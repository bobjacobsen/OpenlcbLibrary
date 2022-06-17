//
//  PIPTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class PIPTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testContainsSingle() {
        let result = PIP.setContents(0x10_00_00_00)
        
        XCTAssertEqual(result, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL]))
    }

    func testContainsMultiple() {
        let result = PIP.setContents(0x10_10_00_00)
        
        XCTAssertEqual(result, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL, PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))
    }
    
    func testContainsFromRaw2() {
        let array : [UInt8] = [0x10, 0x10]
        let result = PIP.setContents(raw: array)
  
        XCTAssertEqual(result, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL, PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))
    }

    func testContentsNameUInt() {
        let result = PIP.contentsNames(0x10_00_00)

        XCTAssertEqual(result, ["SIMPLE_NODE_IDENTIFICATION_PROTOCOL"])
    }

    func testContentsNameUSet() {
        let result = PIP.contentsNames(Set([PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))

        XCTAssertEqual(result, ["Simple Node Identification Protocol"])
    }
}
