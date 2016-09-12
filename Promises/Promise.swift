import Foundation
import Queue


public enum Resolution<V> {
    case completed(value: V)
    case failed(error: Error)
}


open class Promise<V> {
    fileprivate let queue: Queue
    fileprivate var resolution: Resolution<V>? = nil
    var once: Int = 0

    init(_ queue: Queue, block: (() -> (Resolution<V>))? = nil) {
        self.queue = queue
        if let b = block {
            queue.async {
                self.resolution = b()
            }
        }
    }
    
    /// returns the resolved value
    ///
    /// - returns: the value, or nil if the promise is unresolved or resolved 
    ///   to an error
    open var value: V! {
        get {
            switch self.resolution! {
            case .completed(let value):
                return value
            case .failed:
                return nil
            }
        }
    }

    /// returns the resolved error
    ///
    /// - returns: the error, or nil if the promise is unresolved or resolved 
    ///   to a value
    open var error: Error! {
        get {
            switch self.resolution! {
            case .completed:
                return nil
            case .failed(let error):
                return error
            }
        }
    }

    /// returns true if the promise has been resolved
    ///
    /// - returns: a boolean value indicating whether or not the promise has 
    ///   been resolved
    open var isFulfilled: Bool {
        get {
            return resolution != nil
        }
    }
    
    /// schedules a block to be executed when the promise resolves to a value
    ///
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func then(_ block: @escaping (V) -> ()) -> Self {
        resolved { resolution in
            switch resolution {
            case .completed(let value):
                block(value)
            case .failed:
                break
            }
        }
        return self
    }

    /// schedules a block to be executed on the given execution queue, when 
    /// the promise resolves to a value
    ///
    /// - parameter on: the queue to dispatch the block to
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func then(on executionQueue: Queue, _ block: @escaping (V) -> ()) -> Self {
        resolved { resolution in
            switch resolution {
            case .completed(let value):
                executionQueue.async { block(value) }
            case .failed:
                break
            }
        }
        return self
    }

    /// schedules a block to be executed when the promise resolves to a value
    /// and uses the return value of that block as the resolution to a new 
    /// promise.  any error thrown will cause the returned promise to resolve
    /// as failed.
    ///
    /// - returns: a promise of the same type as the return value of the given 
    ///   block, for chaining calls
    open func then<R>(_ block: @escaping (V) throws -> (R)) -> Promise<R> {
        return Promise<R>(self.queue) {
            switch self.resolution! {
            case .completed(let value):
                do {
                    return .completed(value: try block(value))
                } catch (let error) {
                    return .failed(error: error)
                }
            case .failed(let error):
                return .failed(error: error)
            }
        }
    }

    /// schedules a block to be executed on the given execution queue, when
    /// the promise resolves to a value and uses the return value of that block
    /// as the resolution to a new promise.  any error thrown will cause the 
    /// returned promise to resolve as failed.
    ///
    /// - parameter on: the queue to dispatch the block to
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type as the return value of the given
    ///   block, for chaining calls
    open func then<R>(on executionQueue: Queue, _ block: @escaping (V) throws -> (R)) -> Promise<R> {
        let pr = Promise<R>(Queue().suspend())
        resolved { resolution in
            executionQueue.async {
                switch resolution {
                case .completed(let value):
                    do {
                        pr.resolve(.completed(value: try block(value)))
                    } catch (let error) {
                        pr.resolve(.failed(error: error))
                    }
                case .failed(let error):
                    pr.resolve(.failed(error: error))
                }
            }
        }
        return pr
    }

    /// schedules a block to be executed when the promise resolves to an error
    ///
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func error(_ block: @escaping (Error) -> ()) -> Self {
        resolved { resolution in
            switch resolution {
            case .completed:
                break
            case .failed(let error):
                block(error)
            }
        }
        return self
    }

    /// schedules a block to be executed on the given execution queue, when the 
    /// promise resolves to an error
    ///
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func error(on executionQueue: Queue, _ block: @escaping (Error) -> ()) -> Self {
        always {
            switch self.resolution! {
            case .completed:
                break
            case .failed(let error):
                executionQueue.async { block(error) }
            }
        }
        return self
    }

    /// schedules a block to be executed when the promise resolves to an error
    /// and uses the block's result as the resolution to a new promise.  this
    /// allows an error to be converted into success.
    ///
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func recover(_ block: @escaping (Error) throws -> (V)) -> Promise<V> {
        return Promise<V>(self.queue) {
            switch self.resolution! {
            case .completed:
                return self.resolution!
            case .failed(let error):
                do {
                    return .completed(value: try block(error))
                } catch (let error) {
                    return .failed(error: error)
                }
            }
        }
    }

    /// schedules a block to be executed on the given execution queue, when the 
    /// promise resolves to an error and uses the block's result as the 
    /// resolution to a new promise.  this allows an error to be converted into 
    /// success.
    ///
    /// - parameter on: the queue to dispatch the block to
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func recover(on executionQueue: Queue, _ block: @escaping (Error) throws -> (V)) -> Promise<V> {
        let pv = Promise(Queue().suspend())
        resolved { resolution in
            executionQueue.async {
                switch resolution {
                case .completed:
                    pv.resolve(resolution)
                case .failed(let error):
                    do {
                        pv.resolve(.completed(value: try block(error)))
                    } catch (let error) {
                        pv.resolve(.failed(error: error))
                    }
                }
            }
        }
        return pv
    }

    /// schedules a block to be executed when the promise is resolved
    ///
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func always(_ block: @escaping ()->()) -> Self {
        queue.async(block)
        return self
    }

    /// schedules a block to be executed on the given execution queue when the 
    /// promise is resolved.
    ///
    /// - parameter on: the queue to dispatch the block to
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func always(on executionQueue: Queue, block: @escaping ()->()) -> Self {
        queue.async { executionQueue.async(block) }
        return self
    }

    /// schedules a block to be executed on the given execution queue when the
    /// promise is resolved, passing the resolution
    ///
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    open func resolved(_ block: @escaping (Resolution<V>)->()) -> Self {
        queue.async { block(self.resolution!) }
        return self
    }

    
    // Internal Methods
    
    func resolve(_ resolution: Resolution<V>) {
        _ = self.once
    }
}


public func promise<V>(on executionQueue: Queue = .Background, executor: @escaping ( @escaping (V)->(), @escaping (Error)->())->()) -> Promise<V> {
    let p = Promise<V>(Queue().suspend())
    executionQueue.async {
        let resolve = { (value: V) in
            p.resolve(.completed(value: value))
        }
        let reject = { error in
            p.resolve(.failed(error: error))
        }
        executor(resolve, reject)
    }
    return p
}


public func promise<V>(on executionQueue: Queue = .Background, executor: @escaping () throws -> V) -> Promise<V> {
    let p = Promise<V>(Queue().suspend())
    executionQueue.async {
        do {
            p.resolve(.completed(value: try executor()))
        } catch (let error) {
            p.resolve(.failed(error: error))
        }
    }
    return p
}

public func fulfill<V>(_ value: V) -> Promise<V> {
    let p = Promise<V>(Queue().suspend())
    p.resolve(.completed(value: value))
    return p
}

public func when<V>(_ promises: [Promise<V>]) -> Promise<[V]> {
    let syncQueue: Queue = Queue()
    
    return promise { resolve, reject in
        var apr = [V?](repeating: nil, count: promises.count)
        var i = 0
        var remaining = Int32(promises.count)
        var failedWithError: Error? = nil
        for each in promises {
            let index = i
            i += 1
            each.then { value in
                syncQueue.sync {
                    apr[index] = value
                }
                if nil == failedWithError && 0 == OSAtomicDecrement32(&remaining) {
                    resolve(apr.map({ $0! }))
                }
            }.error { error in
                if nil == failedWithError {
                    failedWithError = error
                    reject(error)
                }
            }
        }
    }
}


public func when<V>(_ promises: Promise<V>...) -> Promise<[V]> {
    return when(promises)
}


public func first<V>(_ promises: [Promise<V>]) -> Promise<V> {
    let p = Promise<V>(Queue().suspend())
    for each in promises {
        each.then { value in
            p.resolve(.completed(value: value))
        }.error { error in
            p.resolve(.failed(error: error))
        }
    }
    return p
}


public func first<V>(_ promises: Promise<V>...) -> Promise<V> {
    return first(promises)
}
