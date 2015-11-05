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
            .always {
                print(v)
            }

        waitForExpectationsWithTimeout(3) { error in
        }
        
        XCTAssert("46" == v)
        XCTAssert(e == nil)
    }
    
}
