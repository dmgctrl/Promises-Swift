import XCTest
import Promises

class PromisesTests: XCTestCase {
    
    func test() {
        let expectation = expectationWithDescription("promise completes")
        var v = ""
        var e: ErrorType?
        
        promise { () -> Int in
                23
            }
            .then { i in
                i + 23
            }
            .then {
                String($0)
            }
            .then { v in
                print(v)
            }
            .then {
                v = $0
            }
            .error { error in
                e = error
            }
            .always {
                print(v)
            }
            .then {
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(3) { error in
        }
        
        XCTAssert("46" == v)
        XCTAssert(e == nil)
    }
 
    func test2() {
        let expectation = expectationWithDescription("promise completes")

        _ = promise {
            print("23")
        }.then {
            print($0)
        }.then {
            return 23
        }.then { i in
            print(i)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
        }
    }
    
    func test3() {
        
        let expectation = expectationWithDescription("promise completes")
        
        var promises: [Promise<Int>] = []
        
        var i = 0
        for (;i < 3; i++) {
            let p = promise { resolve, reject in
                resolve(i)
            }
            promises.append(p)
        }
        
        let resolved: Promise<[Int]> = when(promises)
        
        resolved.then { ints in
            assert(ints[0] == 0)
            assert(ints[2] == 2)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
        }
    }
}
