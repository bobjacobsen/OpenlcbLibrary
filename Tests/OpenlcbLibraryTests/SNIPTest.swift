//
//  SNIPTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class SNIPTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitialValue() {
        let snip = SNIP()
        XCTAssertEqual(snip.hardwareVersion, "", "Not nil")
    }
    
    func testGetString() {
        var s = SNIP() // init to all zeros
        s.data = Array(repeating: 0x41, count: 253)
        s.data[4] = 0
        XCTAssertEqual(s.getString(first : 1, maxLength : 5),"AAA")
  
        s.data = Array(repeating: 0x41, count: 253)  // no trailing zero
        XCTAssertEqual(s.getString(first : 1, maxLength : 5),"AAAAA")
    }

    func testLoadAndGetShort() {
        var s = SNIP() // init to all zeros
        s.data = Array(repeating: 0x41, count: 253)

        s.addData(data : [4, 0x41, 0x42, 0x43, 0]) // version + "ABC"
        XCTAssertEqual(s.data[3], 0x43)
        
        s.addData(data : [0x44, 0x45, 0x46, 0]) // DEF
        XCTAssertEqual(s.data[7], 0x46)
        
        s.addData(data : [0x31, 0x45, 0x46, 0]) // 1EF
        s.addData(data : [0x32, 0x45, 0x46, 0])
        s.addData(data : [2])                   // 2nd version string
        s.addData(data : [0x33, 0x45, 0x46, 0])
        s.addData(data : [0x34, 0x45, 0x46, 0])

        XCTAssertEqual(s.getString(n: 0),"ABC")
        XCTAssertEqual(s.getString(n: 1),"DEF")
        XCTAssertEqual(s.getString(n: 2),"1EF")
        XCTAssertEqual(s.getString(n: 3),"2EF")
        XCTAssertEqual(s.getString(n: 4),"3EF")
        XCTAssertEqual(s.getString(n: 5),"4EF")

    }
}
