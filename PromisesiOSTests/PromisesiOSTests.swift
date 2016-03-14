import XCTest
import UIKit
import Promises

class PromisesiOSTests: XCTestCase {
    
    func test1() {
        
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
    
}
