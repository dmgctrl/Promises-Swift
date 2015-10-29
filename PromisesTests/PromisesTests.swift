import XCTest
import Promises

class PromisesTests: XCTestCase {
    
    func test() {
        let expectation = expectationWithDescription("promise completes")
        var v = ""
        var e: NSError?
        
        promise { () -> Int in
                23
            }
            .then {
                $0 + 23
            }
            .then {
                String($0)
            }
            .then {
                v = $0
            }
            .error { error in
                e = error
            }
            .then {
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(3) { error in
        }
        
        XCTAssert("46" == v)
        XCTAssert(e == nil)
    }
    
}
