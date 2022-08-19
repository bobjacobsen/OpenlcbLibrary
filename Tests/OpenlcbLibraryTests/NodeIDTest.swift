//
//  NodeIDTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class NodeIDTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitString() {
        let nid = NodeID("0A.0B.0C.0D.0E.0F")
        XCTAssertEqual(nid.description, "0A.0B.0C.0D.0E.0F")
    }

    func testInvalidInitString() {
        let nid = NodeID("foo")
        XCTAssertEqual(nid.description, "00.00.00.00.00.00")
    }
    func testDescription() {
        let nid = NodeID(0x0A_0B_0C_0D_0E_0F)
        XCTAssertEqual(nid.description, "0A.0B.0C.0D.0E.0F")
 
        let nid2 = NodeID(0xFA_FB_FC_FD_FE_FF)
        XCTAssertEqual(nid2.description, "FA.FB.FC.FD.FE.FF")
    }
    
    func testEquality() {
        let nid12 = NodeID(12)
        let nid12a = NodeID(12)
        let nid13 = NodeID(13)
        XCTAssertEqual(nid12, nid12a, "same contents equal")
        XCTAssertNotEqual(nid12, nid13, "different contents not equal")
        
        let nidDef1 = NodeID(0x05_01_01_01_03_01)
        let nidDef2 = NodeID(0x05_01_01_01_03_01)
        XCTAssertEqual(nidDef1, nidDef2, "default contents equal")
    }
    
    func testToArray() {
        let arr : [UInt8] = NodeID(0x05_01_01_01_03_01).toArray()
        XCTAssertEqual(arr, [UInt8(5), UInt8(1), UInt8(1), UInt8(1), UInt8(3), UInt8(1), ])
        XCTAssertEqual(NodeID(arr), NodeID(0x05_01_01_01_03_01), "array operations")
    }
}
