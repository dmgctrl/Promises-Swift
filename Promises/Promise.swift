import Foundation
import Queue


public class Promise<V> {
    public var resolved: Bool {
        get {
            return value != nil || error != nil
        }
    }
    private(set) public var value: V?
    private(set) public var error: NSError?
    let queue = Queue().suspend()
    let targetQueue: Queue
    var executionQueue: Queue
    var once: dispatch_once_t = 0
    
    public init(targetQueue: Queue = .Background, executionQueue: Queue = .Main) {
        if targetQueue != .Background {
            queue.withTarget(targetQueue)
        }
        self.targetQueue = targetQueue
        self.executionQueue = executionQueue
    }
    
    //  Class Methods
    //
    
    public class func all<R>(promises: [Promise<R>]) -> Promise<[R]> {
        var promise = Promise<[R]>()
        var apr = [R?](count: promises.count, repeatedValue: nil)
        var i = 0
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
                }.catch { error in
                    if  0 == promise.once {
                        promise.reject(error)
                    }
            }
        }
        return promise
    }
    
    public class func all<R>(promises: Promise<R>...) -> Promise<[R]> {
        return all(promises)
    }
    
    //  Public Methods
    //
    
    public func on(executionQueue: Queue) -> Self {
        self.executionQueue = executionQueue
        return self
    }
    
    public func then(block: (V)->()) -> Self {
        let executionQueue = self.executionQueue
        queue.async {
            if let value = self.value {
                if executionQueue != self.targetQueue {
                    executionQueue.async {
                        block(value)
                    }
                } else {
                    block(value)
                }
            }
        }
        return self
    }
    
    public func then<R>(block: (V)->(R)) -> Promise<R> {
        let executionQueue = self.executionQueue
        let promise = Promise<R>(targetQueue: self.targetQueue, executionQueue: self.executionQueue)
        queue.async {
            if let value = self.value {
                if executionQueue != self.targetQueue {
                    executionQueue.async {
                        promise.resolve(block(value))
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
    
    public func then<R>(block: (V)->(Promise<R>)) -> Promise<R> {
        let executionQueue = self.executionQueue
        let promise = Promise<R>(targetQueue: self.targetQueue, executionQueue: self.executionQueue)
        queue.async {
            if let value = self.value {
                if executionQueue != self.targetQueue {
                    executionQueue.async {
                        promise.resolve(block(value))
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
    
    public func catch(block: (NSError)->()) -> Self {
        let executionQueue = self.executionQueue
        queue.async {
            if let error = self.error {
                if executionQueue != self.targetQueue {
                    executionQueue.async {
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
            }.catch { error in
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


public func promise(block: ()->()) -> Promise<Void> {
    let p = Promise<Void>()
    Queue.Background.async {
        block()
        p.resolve()
    }
    return p
}


public func promise<V>(block: ()->V) -> Promise<V> {
    let p = Promise<V>()
    Queue.Background.async {
        let result = block()
        p.resolve(result)
    }
    return p
}
