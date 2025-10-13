//
//  TurnoutModelTest.swift
//  
//
//  Created by Bob Jacobsen on 10/3/22.
//

import XCTest
@testable import OpenlcbLibrary

final class TurnoutModelTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Test cases from a UWT-100 (rev 3) throttle and the TN for Event Protocol
    func testTransmogrification() {
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 1), 0x0008)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 2), 0x000A)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 3), 0x000C)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 4), 0x000E)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 5), 0x0010)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 8), 0x0016)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 9), 0x0018)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 16), 0x0026)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 17), 0x0028)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 32), 0x0046)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 33), 0x0048)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 252), 0x1FE)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 256), 0x0206)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 257), 0x0208)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 513), 0x408)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 2040), 0xFF6)

        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from:  509), 0x400)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 2044), 0xFFE)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 2045), 0x000)
        XCTAssertEqual(TurnoutModel.transmogrifyModelId(from: 2048), 0x006)
    }

}
