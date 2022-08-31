//
//  LocalEventStoreTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class LocalEventStoreTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBasics() {
        let store = LocalEventStore()
        
        store.consumes(EventID(2))
        XCTAssertTrue(store.isConsumed(EventID(2)))
        XCTAssertFalse(store.isConsumed(EventID(3)))

        store.produces(EventID(4))
        XCTAssertTrue(store.isProduced(EventID(4)))
        XCTAssertFalse(store.isProduced(EventID(5)))
    }
}
