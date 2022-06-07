//
//  EventTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class EventTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDescription() {
        let eid = EventID(0x08090A0B0C0D0E0F)
        XCTAssertEqual(Event(eid).description, "Event (EventID 08.09.0A.0B.0C.0D.0E.0F)")
    }

    func testEquatable() {
        let eid12 = EventID(12)
        let e12 = Event(eid12)
        
        let eid12a = EventID(12)
        let e12a = Event(eid12a)
        
        let eid13 = EventID(13)
        let e13 = Event(eid13)
        

        XCTAssertEqual(e12, e12a)
        XCTAssertNotEqual(e12, e13)
    }

    func testHash() {
        let eid12 = EventID(12)
        let e12 = Event(eid12)
        
        let eid12a = EventID(12)
        let e12a = Event(eid12a)
        
        let eid13 = EventID(13)
        let e13 = Event(eid13)
 
        let testSet = Set([e12, e12a, e13])
        XCTAssertEqual(testSet, Set([e12, e13]))
    }
}
