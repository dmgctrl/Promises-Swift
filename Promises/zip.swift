import Foundation


public func zip<A,B>(a: Promise<A>, _ b: Promise<B>) -> Promise<(a: A, b: B)> {
    return promise { resolve, reject in
        var av: A? = nil
        var bv: B? = nil
        var countdown: Int32 = 2
        let tick = {
            if 0 == OSAtomicDecrement32(&countdown) {
                resolve((av!, bv!))
            }
        }
        a.then { v in av = v; tick() }.error(reject)
        b.then { v in bv = v; tick() }.error(reject)
    }
}


public func zip<A,B,C>(a: Promise<A>, _ b: Promise<B>, _ c: Promise<C>) -> Promise<(a: A, b: B, c:C)> {
    return promise { resolve, reject in
        var av: A? = nil
        var bv: B? = nil
        var cv: C? = nil
        var countdown: Int32 = 3
        let tick = {
            if 0 == OSAtomicDecrement32(&countdown) {
                resolve((av!, bv!, cv!))
            }
        }
        a.then { v in av = v; tick() }.error(reject)
        b.then { v in bv = v; tick() }.error(reject)
        c.then { v in cv = v; tick() }.error(reject)
    }
}


public func zip<A,B,C,D>(a: Promise<A>, _ b: Promise<B>, _ c: Promise<C>, _ d: Promise<D>) -> Promise<(a: A, b: B, c:C, d:D)> {
    return promise { resolve, reject in
        var av: A? = nil
        var bv: B? = nil
        var cv: C? = nil
        var dv: D? = nil
        var countdown: Int32 = 4
        let tick = {
            if 0 == OSAtomicDecrement32(&countdown) {
                resolve((av!, bv!, cv!, dv!))
            }
        }
        a.then { v in av = v; tick() }.error(reject)
        b.then { v in bv = v; tick() }.error(reject)
        c.then { v in cv = v; tick() }.error(reject)
        d.then { v in dv = v; tick() }.error(reject)
    }
}


public func zip<A,B,C,D,E>(a: Promise<A>, _ b: Promise<B>, _ c: Promise<C>, _ d: Promise<D>, _ e: Promise<E>) -> Promise<(a: A, b: B, c:C, d:D, e:E)> {
    return promise { resolve, reject in
        var av: A? = nil
        var bv: B? = nil
        var cv: C? = nil
        var dv: D? = nil
        var ev: E? = nil
        var countdown: Int32 = 5
        let tick = {
            if 0 == OSAtomicDecrement32(&countdown) {
                resolve((av!, bv!, cv!, dv!, ev!))
            }
        }
        a.then { v in av = v; tick() }.error(reject)
        b.then { v in bv = v; tick() }.error(reject)
        c.then { v in cv = v; tick() }.error(reject)
        d.then { v in dv = v; tick() }.error(reject)
        e.then { v in ev = v; tick() }.error(reject)
    }
}
