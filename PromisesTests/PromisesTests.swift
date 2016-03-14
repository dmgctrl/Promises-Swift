import XCTest
import Promises
import UIKit

enum PromisesTestsError: ErrorType {
    case TestError
}

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

        for (var i = 0; i < 3; i++) {
            let index = i
            let p = promise { resolve, reject in
                resolve(index)
            }
            promises.append(p)
        }
        
        let resolved: Promise<[Int]> = when(promises)
        
        resolved.then { ints in
            assert(ints[0] == 0)
            assert(ints[1] == 1)
            assert(ints[2] == 2)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
        }
    }
    
    func test4() {
        
        let expectation = expectationWithDescription("promise fails")
        
        var promises: [Promise<Int>] = []
        
        for (var i = 0; i < 3; i++) {
            let p = promise() { () -> Int in
                throw PromisesTestsError.TestError
            }
            promises.append(p)
        }
        
        let resolved: Promise<[Int]> = when(promises)
        
        resolved.error { error in
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
        }
    }
    
    func test5() {
        
        let expectation = expectationWithDescription("promise completes")
        
        var promises: [Promise<UIView>] = []
        
        for (var i = 0; i < 3; i++) {
            let p = promise() { () -> UIView in
                let rect = CGRect(
                    origin: CGPoint(x: 0, y: 0),
                    size: CGSize(width: 10, height: 10)
                )
                let view = UIView(frame: rect)
                return view
            }
            promises.append(p)
        }
        
        let resolved: Promise<[UIView]> = when(promises)
        
        resolved.then { views in
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
        }
    }
    
    func testFulfill() {
        
        let p = fulfill(5)
        
        XCTAssert(p.isFulfilled == true)
    }
}
