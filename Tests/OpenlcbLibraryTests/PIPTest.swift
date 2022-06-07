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
        let result = PIP.contains(0x10_00_00_00)
        
        XCTAssertEqual(result, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL]))
    }

    func testContainsMultiple() {
        let result = PIP.contains(0x10_10_00_00)
        
        XCTAssertEqual(result, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL, PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))
    }
    
    func testContainsFromRaw2() {
        let array : [UInt8] = [0x10, 0x10]
        let result = PIP.contains(raw: array)
        
        XCTAssertEqual(result, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL, PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))
    }

}
