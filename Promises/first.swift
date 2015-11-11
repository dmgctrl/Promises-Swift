import Queue


public func first<V>(promises: [Promise<V>]) -> Promise<V> {
    let p = Promise<V>(Queue().suspend())
    for each in promises {
        each.then { value in
            p.resolve(.Completed(value: value))
        }.error { error in
            p.resolve(.Failed(error: error))
        }
    }
    return p
}


public func first<V>(promises: Promise<V>...) -> Promise<V> {
    return first(promises)
}
