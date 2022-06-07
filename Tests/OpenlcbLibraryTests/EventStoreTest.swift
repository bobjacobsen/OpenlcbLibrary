//
//  EventStoreTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class EventStoreTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSimpleLoadStore() {
        var store = EventStore()
        
        let e12 = Event(EventID(12))
        
        store.store(e12)
        store.store(Event(EventID(13)))
        
        XCTAssertEqual(store.lookup(EventID(12)), e12, "store then lookup OK")
    }

    func testAccessThroughLoadStoreByID() {
        var store = EventStore()
        
        let eid12 = EventID(12)
        let eid13 = EventID(13)

        let e12 = Event(eid12)
        let e13 = Event(eid13)

        store.store(e12)
        store.store(e13)
                
        // lookup non-existing node creates it
        XCTAssertEqual(store.lookup(EventID(21)), Event(EventID(21)), "create on no match in store")
        
        let temp = store.lookup(eid13)
        store.store(temp)
        XCTAssertEqual(store.lookup(eid13), temp, "original in store modified by replacement")
    }
}
