import Foundation


public func when<V>(promises: [Promise<V>]) -> Promise<[V]> {
    return promise { resolve, reject in
        var apr = [V?](count: promises.count, repeatedValue: nil)
        let i = 0
        var remaining = Int32(promises.count)
        for each in promises {
            each.then { value in
                apr[i] = value
                if 0 == OSAtomicDecrement32(&remaining) {
                    var ar = [V]()
                    for pr in apr {
                        ar.append(pr!)
                    }
                    resolve(ar)
                }
            }.error(reject)
        }
    }
}


public func when<V>(promises: Promise<V>...) -> Promise<[V]> {
    return when(promises)
}


