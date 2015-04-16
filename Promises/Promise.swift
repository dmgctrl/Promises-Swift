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
    var once: dispatch_once_t = 0
    
    public init(executionQueue: Queue? = .Main) {
        if executionQueue != nil {
            queue.withTarget(executionQueue!)
        }
    }
    
    //  Class Methods
    //
    
    public class func all<R>(promises: [Promise<R>]) -> Promise<[R]> {
        return promise { resolve, reject in
            var apr = [R?](count: promises.count, repeatedValue: nil)
            var i = 0
            var remaining = promises.count
            var once: dispatch_once_t = 0
            for each in promises {
                each.then { value in
                    apr[i] = value
                    if 0 == --remaining {
                        dispatch_once(&once) {
                            var ar = [R]()
                            for pr in apr {
                                ar.append(pr!)
                            }
                            resolve(ar)
                        }
                    }
                }.catch { error in
                    dispatch_once(&once) {
                        reject(error)
                    }
                }
            }
        }
    }
    
    public class func all<R>(promises: Promise<R>...) -> Promise<[R]> {
        return all(promises)
    }
    
    //  Variations on then()
    //

    public func then(block: (V)->()) -> Self {
        self.queue.async {
            if let value = self.value {
                block(value)
            }
        }
        return self
    }
    
    public func then(onQueue queue: Queue, block: (V)->()) -> Self {
        self.queue.async {
            if let value = self.value {
                queue.async {
                    block(value)
                }
            }
        }
        return self
    }

    public func then<R>(map: (V)->(R)) -> Promise<R> {
        return promise(onQueue: self.queue) { resolve, reject in
            if let value = self.value {
                resolve(map(value))
            } else {
                reject(self.error!)
            }
        }
    }
    
    public func then<R>(onQueue queue: Queue, map: (V)->(R)) -> Promise<R> {
        return promise(onQueue: self.queue) { resolve, reject in
            if let value = self.value {
                queue.async {
                    resolve(map(value))
                }
            } else {
                reject(self.error!)
            }
        }
    }
    
    public func then<R>(map: (V)->(Promise<R>)) -> Promise<R> {
        return promise(onQueue: self.queue) { resolve, reject in
            if let value = self.value {
                map(value).then(resolve).catch(reject)
            } else {
                reject(self.error!)
            }
        }
    }
    
    public func then<R>(onQueue queue: Queue, map: (V)->(Promise<R>)) -> Promise<R> {
        return promise(onQueue: self.queue) { resolve, reject in
            if let value = self.value {
                queue.async {
                    _ = map(value).then(resolve).catch(reject)
                }
            } else {
                reject(self.error!)
            }
        }
    }

    //  Variations on catch()
    //
    
    public func catch(block: (NSError)->()) -> Self {
        self.queue.async {
            if let error = self.error {
                block(error)
            }
        }
        return self
    }
    
    public func catch(onQueue queue: Queue, block: (NSError)->()) -> Self {
        self.queue.async {
            if let error = self.error {
                queue.async {
                    block(error)
                }
            }
        }
        return self
    }

    //  Resolution
    //
    
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
            _ = promise.then { value in
                self.value = value
                self.queue.resume()
            }.catch { error in
                self.error = error
                self.queue.resume()
            }
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
