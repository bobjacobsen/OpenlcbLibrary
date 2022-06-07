//
//  CanFrameTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class CanFrameTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInit() {
        let frame1 = CanFrame(header:0, data:[])
        XCTAssertEqual(frame1.header, 0x0_000_000)
        XCTAssertEqual(frame1.data, [])

        let frame2 = CanFrame(header:0x1234, data:[])
        XCTAssertEqual(frame2.header, 0x1234)
        XCTAssertEqual(frame2.data, [])

        let frame3 = CanFrame(header:0x123456, data:[1,2,3])
        XCTAssertEqual(frame3.header, 0x123456)
        XCTAssertEqual(frame3.data, [1,2,3])
    }
    
    func testCID() throws {
        let cidFrame40 = CanFrame(cid: 4, nodeID: NodeID(0x00_00_00_00_00_00), alias: 0)
        XCTAssertEqual(cidFrame40.header, 0x4_000_000)
        XCTAssertEqual(cidFrame40.data, [])

        let cidFrame4ABC = CanFrame(cid: 4, nodeID: NodeID(0x00_00_00_00_00_00), alias: 0xABC)
        XCTAssertEqual(cidFrame4ABC.header, 0x4_000_ABC)
        XCTAssertEqual(cidFrame4ABC.data, [])

        let cidFrame4 = CanFrame(cid: 4, nodeID: NodeID(0x12_34_56_78_9A_BC), alias: 0x123)
        XCTAssertEqual(cidFrame4.header, 0x4_ABC_123)
        XCTAssertEqual(cidFrame4.data, [])

        let cidFrame5 = CanFrame(cid: 5, nodeID: NodeID(0x12_34_56_78_9A_BC), alias: 0x321)
        XCTAssertEqual(cidFrame5.header, 0x5_789_321)
        XCTAssertEqual(cidFrame5.data, [])

        let cidFrame7 = CanFrame(cid: 7, nodeID: NodeID(0x12_34_56_78_9A_BC), alias: 0x010)
        XCTAssertEqual(cidFrame7.header, 0x7_123_010)
        XCTAssertEqual(cidFrame7.data, [])
    }

    func testControlFrame() throws {
        let frame0703 = CanFrame(control : 0x0701, alias : 0x123)
        XCTAssertEqual(frame0703.header, 0x0_701_123)
        XCTAssertEqual(frame0703.data, [])
    }
}
