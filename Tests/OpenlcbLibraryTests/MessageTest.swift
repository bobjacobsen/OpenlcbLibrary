//
//  MessageTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class MessageTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDescription3Args() {
        let message = Message(mti : MTI.Identify_Consumer, source : NodeID(12), destination : NodeID(13))
        XCTAssertEqual(message.description, "Message (Identify_Consumer)")
    }

    func testDescription2Args() {
        let message = Message(mti : MTI.Identify_Consumer, source : NodeID(12))
        XCTAssertEqual(message.description, "Message (Identify_Consumer)")
    }
    
    func testGlobalAddressed() {
        XCTAssertTrue(Message(mti:.Initialization_Complete, source:NodeID(0)).isGlobal())
        XCTAssertFalse(Message(mti:.Initialization_Complete, source:NodeID(0)).isAddressed())

        XCTAssertTrue(Message(mti:.Verify_NodeID_Number_Addressed, source:NodeID(0)).isAddressed())
        XCTAssertFalse(Message(mti:.Verify_NodeID_Number_Addressed, source:NodeID(0)).isGlobal())
    }

    func testHash() {
        let m1 = Message(mti : MTI.Identify_Consumer, source : NodeID(12), data: [1,2,3])
        let m1a = Message(mti : MTI.Identify_Consumer, source : NodeID(12), data: [3,2,1])

        let m2 = Message(mti : MTI.Identify_Consumer, source : NodeID(13))
        let m2a = Message(mti : MTI.Identify_Consumer, source : NodeID(13))

        let testSet = Set([m1, m1a, m2, m2a])
        XCTAssertEqual(testSet, Set([m1, m1a, m2]))
    }
}
