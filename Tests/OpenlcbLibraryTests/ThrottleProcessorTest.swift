//
//  ThrottleProcessorTest.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import XCTest
@testable import OpenlcbLibrary

final class ThrottleProcessorTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPCERmatch() throws {
        let node1 = Node(NodeID(1))
        let model = ThrottleModel()
        // clear debug content, if any
        model.roster = []
        
        let put = ThrottleProcessor(nil, model: model)
        
        let pcerMatch =   Message(mti:.Producer_Consumer_Event_Report, source: NodeID(10), data: [1,1,0,0,0,0,3,3]) // isATrain event
        let pcerNoMatch = Message(mti:.Producer_Consumer_Event_Report, source: NodeID(11), data: [1,1,0,0,0,0,3,0]) // mismatch in last entry
        let piaMatch =   Message(mti:.Producer_Identified_Active, source: NodeID(12), data: [1,1,0,0,0,0,3,3]) // isATrain event

        put.process(pcerMatch, node1)
        put.process(pcerNoMatch, node1)
        put.process(piaMatch, node1)

        XCTAssertEqual(model.roster.count, 2)
        XCTAssertTrue(model.roster.contains(RosterEntry("10", NodeID(10))))
        XCTAssertFalse(model.roster.contains(RosterEntry("11", NodeID(11))))
        XCTAssertTrue(model.roster.contains(RosterEntry("12", NodeID(12))))
    }
}
