import Foundation
import Queue


public class Promise<V> {
    private(set) public var value: V?
    private(set) public var error: NSError?
    let queue = Queue().suspend()
    let targetQueue: Queue
    var once: dispatch_once_t = 0
    
    public init(targetQueue: Queue = .Background) {
        if targetQueue != .Background {
            queue.withTarget(targetQueue)
        }
        self.targetQueue = targetQueue
    }
    
    //  Public Methods
    //

    public var isFulfilled: Bool {
        get {
            return once != 0
        }
    }

    public func then(on executionQueue: Queue? = nil, block: (V)->()) -> Self {
        queue.async {
            if let value = self.value {
                if let q = executionQueue where q != self.targetQueue {
                    q.async {
                        block(value)
                    }
                } else {
                    block(value)
                }
            }
        }
        return self
    }
    
    public func then<R>(on executionQueue: Queue? = nil, block: (V)->(R)) -> Promise<R> {
        let promise = Promise<R>(targetQueue: self.targetQueue)
        queue.async {
            if let value = self.value {
                if let q = executionQueue where q != self.targetQueue {
                    q.async {
                        promise.resolve(block(value))
                        return
                    }
                } else {
                    promise.resolve(block(value))
                }
            } else if let error = self.error {
                promise.reject(error)
            }
        }
        return promise
    }
    
    public func then<R>(onQueue executionQueue: Queue? = nil, block: (V)->(Promise<R>)) -> Promise<R> {
        let promise = Promise<R>(targetQueue: self.targetQueue)
        queue.async {
            if let value = self.value {
                if let q = executionQueue where q != self.targetQueue {
                    q.async {
                        promise.resolve(block(value))
                        return
                    }
                } else {
                    promise.resolve(block(value))
                }
            } else if let error = self.error {
                promise.reject(error)
            }
        }
        return promise
    }
    
    public func error(on executionQueue: Queue? = nil, block: (NSError)->()) -> Self {
        queue.async {
            if let error = self.error {
                if let q = executionQueue where q != self.targetQueue {
                    q.async {
                        block(error)
                    }
                } else {
                    block(error)
                }
            }
        }
        return self
    }
    
    public func resolve(value: V) -> Self {
        assert(0 == once, "This promise has already been resolved")
        dispatch_once(&once) {
            self.value = value
            self.queue.resume()
        }
        return self
    }
    
    public func resolve(promise: Promise<V>) -> Self {
        assert(0 == once, "This promise has already been resolved")
        dispatch_once(&once) {
            promise.then { value in
                self.value = value
                self.queue.resume()
            }.error { error in
                self.error = error
                self.queue.resume()
            }
            return
        }
        return self
    }
    
    public func reject(error: NSError) -> Self {
        assert(0 == once, "This promise has already been resolved")
        dispatch_once(&once) {
            self.error = error
            self.queue.resume()
        }
        return self
    }
}


public func all<R>(promises: [Promise<R>]) -> Promise<[R]> {
    let promise = Promise<[R]>()
    var apr = [R?](count: promises.count, repeatedValue: nil)
    let i = 0
    var remaining = promises.count
    for each in promises {
        each.then { value in
            apr[i] = value
            remaining--
            if 0 == remaining && 0 == promise.once {
                var ar = [R]()
                for pr in apr {
                    ar.append(pr!)
                }
                promise.resolve(ar)
            }
            }.error { error in
                if  0 == promise.once {
                    promise.reject(error)
                }
        }
    }
    return promise
}


public func all<R>(promises: Promise<R>...) -> Promise<[R]> {
    return all(promises)
}


public func promise<V>(onQueue queue: Queue = .Background, executor: ((V)->(), (NSError)->())->()) -> Promise<V> {
    let p = Promise<V>()
    queue.async {
        let resolve = { (value: V) in
            _ = p.resolve(value)
        }
        let reject = { error in
            _ = p.reject(error)
        }
        executor(resolve, reject)
        assert(p.isFulfilled, "This promise must be resolved by calling resolve() or reject()")
    }
    return p
}


public func promise<V>(onQueue queue: Queue = .Background, executor: ()->V) -> Promise<V> {
    let p = Promise<V>()
    queue.async {
        _ = p.resolve(executor())
    }
    return p
}


public func promise<V>(onQueue queue: Queue = .Background, executor: ()->Promise<V>) -> Promise<V> {
    let p = Promise<V>()
    queue.async {
        _ = p.resolve(executor())
    }
    return p
}
