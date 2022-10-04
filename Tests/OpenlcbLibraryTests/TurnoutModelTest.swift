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
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 1), 0x0008)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 2), 0x000A)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 3), 0x000C)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 4), 0x000E)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 5), 0x0010)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 8), 0x0016)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 9), 0x0018)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 16), 0x0026)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 17), 0x0028)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 32), 0x0046)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 33), 0x0048)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 252), 0x1FE)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 256), 0x0206)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 257), 0x0208)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 513), 0x408)
        XCTAssertEqual(TurnoutModel.transmogrifyTurnoutId(from: 2040), 0xFF6)
    }

}
