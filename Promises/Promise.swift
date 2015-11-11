import Foundation
import Queue


public enum Resolution<V> {
    case Completed(value: V)
    case Failed(error: ErrorType)
}


public class Promise<V> {
    private let queue: Queue
    private var resolution: Resolution<V>? = nil
    var once: dispatch_once_t = 0

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
    public var value: V! {
        get {
            switch self.resolution! {
            case .Completed(let value):
                return value
            case .Failed:
                return nil
            }
        }
    }

    /// returns the resolved error
    ///
    /// - returns: the error, or nil if the promise is unresolved or resolved 
    ///   to a value
    public var error: ErrorType! {
        get {
            switch self.resolution! {
            case .Completed:
                return nil
            case .Failed(let error):
                return error
            }
        }
    }

    /// returns true if the promise has been resolved
    ///
    /// - returns: a boolean value indicating whether or not the promise has 
    ///   been resolved
    public var isFulfilled: Bool {
        get {
            return resolution != nil
        }
    }
    
    /// schedules a block to be executed when the promise resolves to a value
    ///
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    public func then(block: (V) -> ()) -> Self {
        resolved { resolution in
            switch resolution {
            case .Completed(let value):
                block(value)
            case .Failed:
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
    public func then(on executionQueue: Queue, _ block: (V) -> ()) -> Self {
        resolved { resolution in
            switch resolution {
            case .Completed(let value):
                executionQueue.async { block(value) }
            case .Failed:
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
    public func then<R>(block: (V) throws -> (R)) -> Promise<R> {
        return Promise<R>(self.queue) {
            switch self.resolution! {
            case .Completed(let value):
                do {
                    return .Completed(value: try block(value))
                } catch (let error) {
                    return .Failed(error: error)
                }
            case .Failed(let error):
                return .Failed(error: error)
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
    public func then<R>(on executionQueue: Queue, _ block: (V) throws -> (R)) -> Promise<R> {
        let pr = Promise<R>(Queue().suspend())
        resolved { resolution in
            executionQueue.async {
                switch resolution {
                case .Completed(let value):
                    do {
                        pr.resolve(.Completed(value: try block(value)))
                    } catch (let error) {
                        pr.resolve(.Failed(error: error))
                    }
                case .Failed(let error):
                    pr.resolve(.Failed(error: error))
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
    public func error(block: (ErrorType) -> ()) -> Self {
        resolved { resolution in
            switch resolution {
            case .Completed:
                break
            case .Failed(let error):
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
    public func error(on executionQueue: Queue, _ block: (ErrorType) -> ()) -> Self {
        always {
            switch self.resolution! {
            case .Completed:
                break
            case .Failed(let error):
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
    public func recover(block: (ErrorType) throws -> (V)) -> Promise<V> {
        return Promise<V>(self.queue) {
            switch self.resolution! {
            case .Completed:
                return self.resolution!
            case .Failed(let error):
                do {
                    return .Completed(value: try block(error))
                } catch (let error) {
                    return .Failed(error: error)
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
    public func recover(on executionQueue: Queue, _ block: (ErrorType) throws -> (V)) -> Promise<V> {
        let pv = Promise(Queue().suspend())
        resolved { resolution in
            executionQueue.async {
                switch resolution {
                case .Completed:
                    pv.resolve(resolution)
                case .Failed(let error):
                    do {
                        pv.resolve(.Completed(value: try block(error)))
                    } catch (let error) {
                        pv.resolve(.Failed(error: error))
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
    public func always(block: ()->()) -> Self {
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
    public func always(on executionQueue: Queue, block: ()->()) -> Self {
        queue.async { executionQueue.async(block) }
        return self
    }

    /// schedules a block to be executed on the given execution queue when the
    /// promise is resolved, passing the resolution
    ///
    /// - parameter block: the block to execute
    ///
    /// - returns: a promise of the same type, for chaining calls
    public func resolved(block: (Resolution<V>)->()) -> Self {
        queue.async { block(self.resolution!) }
        return self
    }

    
    // Internal Methods
    
    func resolve(resolution: Resolution<V>) {
        dispatch_once(&once) {
            self.resolution = resolution
            self.queue.resume()
        }
    }
}


public func promise<V>(on executionQueue: Queue = .Background, executor: ((V)->(), (ErrorType)->())->()) -> Promise<V> {
    let p = Promise<V>(Queue().suspend())
    executionQueue.async {
        let resolve = { (value: V) in
            p.resolve(.Completed(value: value))
        }
        let reject = { error in
            p.resolve(.Failed(error: error))
        }
        executor(resolve, reject)
    }
    return p
}


public func promise<V>(on executionQueue: Queue = .Background, executor: () throws -> V) -> Promise<V> {
    let p = Promise<V>(Queue().suspend())
    executionQueue.async {
        do {
            p.resolve(.Completed(value: try executor()))
        } catch (let error) {
            p.resolve(.Failed(error: error))
        }
    }
    return p
}
