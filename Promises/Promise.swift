import Foundation
import Queue


public class Promise<V> {
    public var resolved: Bool {
        get {
            return 0 == once
        }
    }
    private(set) public var value: V?
    private(set) public var error: NSError?
    private let queue = Queue().suspend()
    private var once: dispatch_once_t = 0
    
    public init() {
    }
    
    //  Public Methods
    //

    public func then(block: (V)->()) -> Self {
        return then(onQueue: .Main, block)
    }

    public func then(onQueue executionQueue: Queue, block: (V)->()) -> Self {
        queue.async {
            if let value = self.value {
                executionQueue.async {
                    block(value)
                }
            }
        }
        return self
    }
    
    public func then<R>(block: (V)->(R)) -> Promise<R> {
        return then(onQueue: .Main, block)
    }

    public func then<R>(onQueue executionQueue: Queue, block: (V)->(R)) -> Promise<R> {
        let promise = Promise<R>()
        queue.async {
            if let value = self.value {
                executionQueue.async {
                    _ = promise.resolve(block(value))
                }
            } else if let error = self.error {
                promise.reject(error)
            }
        }
        return promise.withValueChain(valueChain)
    }

    public func then<R>(block: (V)->(Promise<R>)) -> Promise<R> {
        return then(onQueue: .Main, block)
    }

    public func then<R>(onQueue executionQueue: Queue, block: (V)->(Promise<R>)) -> Promise<R> {
        let promise = Promise<R>()
        queue.async {
            if let value = self.value {
                executionQueue.async {
                    _ = promise.resolve(block(value))
                }
            } else if let error = self.error {
                promise.reject(error)
            }
        }
        return promise.withValueChain(valueChain)
    }

    public func catch(block: (NSError)->()) -> Self {
        return catch(onQueue: .Main, block)
    }

    public func catch(onQueue executionQueue: Queue, block: (NSError)->()) -> Self {
        queue.async {
            if let error = self.error {
                executionQueue.async {
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
    

    //  Values
    //  ------
    
    var valueChain: Value!
    
    public func valueFor(key: UnsafePointer<Void>) -> Any? {
        var v = valueChain
        while nil != v {
            if v.key == key {
                return v.any
            }
            v = v.parent
        }
        return nil
    }
    
    public func withValue(value: Any, forKey key: UnsafePointer<Void>) -> Self {
        valueChain = Value(parent: valueChain, key: key, any: value)
        return self
    }

    func withValueChain(valueChain: Value?) -> Self {
        self.valueChain = valueChain
        return self
    }
}


class Value {
    let parent: Value?
    let key: UnsafePointer<Void>
    let any: Any
    
    init(parent: Value?, key: UnsafePointer<Void>, any: Any) {
        self.parent = parent
        self.key = key
        self.any = any
    }
}


//  Convenience Methods
//

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
        assert(p.resolved, "This promise must be resolved by calling resolve() or reject()")
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


//  Coalescing Methods
//

public func all<R>(promises: Promise<R>...) -> Promise<[R]> {
    return all(promises)
}

public func all<R>(promises: [Promise<R>]) -> Promise<[R]> {
    let promise = Promise<[R]>()
    var remaining = promises.count
    if remaining > 0 {
        var apr = [R?](count: remaining, repeatedValue: nil)
        var i = 0
        for each in promises {
            each.then { value in
                apr[i] = value
                remaining--
                if 0 == remaining && !promise.resolved {
                    var ar = [R]()
                    for pr in apr {
                        ar.append(pr!)
                    }
                    promise.resolve(ar)
                }
            }.catch { error in
                if !promise.resolved {
                    promise.reject(error)
                }
            }
            i++
        }
    } else {
        promise.resolve([])
    }
    return promise
}

