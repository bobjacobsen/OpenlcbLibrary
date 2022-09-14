//
//  MtiTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class MtiTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitFromInt() {
        XCTAssertEqual(MTI(rawValue: 0x08F4), MTI.Identify_Consumer)
    }

    func testPriority() {
        XCTAssertEqual(MTI(rawValue: 0x08F4)!.priority(),2)
    }

    func testAddressPresent() {
        XCTAssertFalse(MTI(rawValue: 0x08F4)!.addressPresent())
        XCTAssertTrue(MTI(rawValue: 0x0828)!.addressPresent())
    }

    func testEventIDPresent() {
        XCTAssertTrue(MTI(rawValue: 0x08F4)!.eventIDPresent())
        XCTAssertFalse(MTI(rawValue: 0x0828)!.eventIDPresent())
   }

    func testSimpleProtocol() {
        XCTAssertTrue(MTI(rawValue: 0x08F4)!.simpleProtocol())
        XCTAssertFalse(MTI(rawValue: 0x0828)!.simpleProtocol())
    }
    func testIsGlobal() {
        XCTAssertTrue(MTI(rawValue: 0x08F4)!.isGlobal())
        XCTAssertFalse(MTI(rawValue: 0x0828)!.isGlobal())
        XCTAssertTrue(MTI.Initialization_Complete.isGlobal())
        XCTAssertFalse(MTI.Protocol_Support_Inquiry.isGlobal())
        
        XCTAssertTrue(MTI.Link_Layer_Up.isGlobal())     // needs to be global so all node implementations see it
        XCTAssertTrue(MTI.Link_Layer_Down.isGlobal())   // needs to be global so all node implementations see it
    }
}
