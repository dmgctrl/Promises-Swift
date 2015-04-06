import UIKit
import XCTest
import Promises

class PromisesTests: XCTestCase {
    
    func test() {
        let expectation = expectationWithDescription("promise completes")
        var v = ""
        var e: NSError?
        
        let p = promise { () -> Int in
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
                expectation.fulfill()
            }
            .catch { error in
                e = error
            }

        waitForExpectationsWithTimeout(3) { error in
        }
        
        XCTAssert("46" == v)
        XCTAssert(e == nil)
    }
    
}
