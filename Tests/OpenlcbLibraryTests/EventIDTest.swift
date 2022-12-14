//
//  EventIDTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class EventIDTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitString() {
        let eid = EventID("08.09.0A.0B.0C.0D.0E.0F")
        XCTAssertEqual(eid.description, "08.09.0A.0B.0C.0D.0E.0F")
        let eid2 = EventID("FF.09.0A.0B.0C.0D.0E.0F")
        XCTAssertEqual(eid2.description, "FF.09.0A.0B.0C.0D.0E.0F")
        
        let eid3 = EventID("FF.9.A.B.C.D.E.F")
        XCTAssertEqual(eid3.description, "FF.09.0A.0B.0C.0D.0E.0F")
        let eid4 = EventID("A.B.C.D.E.F")
        XCTAssertEqual(eid4.description, "00.00.0A.0B.0C.0D.0E.0F")
        
        let eid5 = EventID("08090A0B0C0D0E0F")
        XCTAssertEqual(eid5.description, "08.09.0A.0B.0C.0D.0E.0F")
    }
    
    func testInitArray() {
        let array : [UInt8] = [8,9,10,11,12,13,14,15]
        let eid = EventID(array)
        XCTAssertEqual(eid.description, "08.09.0A.0B.0C.0D.0E.0F")
        let eid2 = EventID("FF.09.0A.0B.0C.0D.0E.0F")
        XCTAssertEqual(eid2.description, "FF.09.0A.0B.0C.0D.0E.0F")
    }

    func testToArray() {
        let eid = EventID(0x0102030405060708)
        XCTAssertEqual(eid.toArray(), [1,2,3,4,5,6,7,8])
    }
    
    func testInvalidInitString() {
        let eid = EventID("foo")
        XCTAssertEqual(eid.description, "00.00.00.00.00.00.00.00")
    }
    
    func testDescription() {
        let eid = EventID(0x08090A0B0C0D0E0F)
        XCTAssertEqual(eid.description, "08.09.0A.0B.0C.0D.0E.0F")
 
        let eid2 = EventID(0xF8F9FAFBFCFDFEFF)
        XCTAssertEqual(eid2.description, "F8.F9.FA.FB.FC.FD.FE.FF")
    }
    
    func testEquality() {
        let eid12 = EventID(12)
        let eid12a = EventID(12)
        let eid13 = EventID(13)
        XCTAssertEqual(eid12, eid12a, "same contents equal")
        XCTAssertNotEqual(eid12, eid13, "different contents not equal")
    }
}
