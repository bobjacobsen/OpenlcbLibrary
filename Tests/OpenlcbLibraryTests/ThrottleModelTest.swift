//
//  ThrottleModelTest.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import XCTest
@testable import OpenlcbLibrary

final class ThrottleModelTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testcreateQueryEventID() throws {
        var eventID = ThrottleModel.createQueryEventID(matching: 2)
        XCTAssertEqual(EventID([0x09, 0x00, 0x99, 0xFF, 0x2F, 0xFF, 0xFF, 0xE0]), eventID)

        eventID = ThrottleModel.createQueryEventID(matching: 12)
        XCTAssertEqual(EventID([0x09, 0x00, 0x99, 0xFF, 0x12, 0xFF, 0xFF, 0xE0]), eventID)

        eventID = ThrottleModel.createQueryEventID(matching: 123)
        XCTAssertEqual(EventID([0x09, 0x00, 0x99, 0xFF, 0x12, 0x3F, 0xFF, 0xE0]), eventID)

        eventID = ThrottleModel.createQueryEventID(matching: 1234)
        XCTAssertEqual(EventID([0x09, 0x00, 0x99, 0xFF, 0x12, 0x34, 0xFF, 0xE0]), eventID)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
