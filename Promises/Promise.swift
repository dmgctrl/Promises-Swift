import Foundation
import Queue


enum Resolution<V> {
    case Completed(value: V)
    case Failed(error: ErrorType)
}

public class Promise<V> {
    private let queue: Queue
    private var resolution: Resolution<V>? = nil
    var once: dispatch_once_t = 0

    init(queue: Queue, block: (() -> (Resolution<V>))? = nil) {
        self.queue = queue
        if let b = block {
            queue.async {
                self.resolution = b()
            }
        }
    }
    
    public var value: V? {
        get {
            switch self.resolution! {
            case .Completed(let value):
                return value
            case .Failed:
                return nil
            }
        }
    }

    public var error: ErrorType? {
        get {
            switch self.resolution! {
            case .Completed:
                return nil
            case .Failed(let error):
                return error
            }
        }
    }

    public var isFulfilled: Bool {
        get {
            return resolution != nil
        }
    }
    
    public func then(block: (V) -> ()) -> Self {
        queue.async {
            switch self.resolution! {
            case .Completed(let value):
                block(value)
                break
            case .Failed:
                break
            }
        }
        return self
    }

    public func then<R>(block: (V) throws -> (R)) -> Promise<R> {
        return Promise<R>(queue: self.queue) {
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

    public func error(block: (ErrorType) -> ()) -> Self {
        queue.async {
            switch self.resolution! {
            case .Completed:
                break
            case .Failed(let error):
                block(error)
                break
            }
        }
        return self
    }

    public func recover(block: (ErrorType) throws -> (V)) -> Promise<V> {
        return Promise<V>(queue: self.queue) {
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
    
    public func always(block: ()->()) {
        queue.async(block)
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
    let p = Promise<V>(queue: Queue().suspend())
    executionQueue.async {
        var resolution: Resolution<V>? = nil
        let resolve = { (value: V) in
            resolution = .Completed(value: value)
        }
        let reject = { error in
            resolution = .Failed(error: error)
        }
        executor(resolve, reject)
        assert(resolution != nil, "This promise must be resolved by calling resolve() or reject()")
        p.resolve(resolution!)
    }
    return p;
}


public func promise<V>(on executionQueue: Queue = .Background, executor: () throws -> V) -> Promise<V> {
    let p = Promise<V>(queue: Queue().suspend())
    executionQueue.async {
        do {
            p.resolve(.Completed(value: try executor()))
        } catch (let error) {
            p.resolve(.Failed(error: error))
        }
    }
    return p;
}
