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
        let model = ThrottleModel(nil)
        model.openlcbNetwork = OpenlcbNetwork(defaultNodeID: NodeID(1))
        
        // clear debug content, if any
        model.roster = []
        
        let put = ThrottleProcessor(CanLink(localNodeID: NodeID(1)), model: model)
        
        let pcerMatch =   Message(mti:.Producer_Consumer_Event_Report, source: NodeID(10), data: [1,1,0,0,0,0,3,3]) // isATrain event
        let pcerNoMatch = Message(mti:.Producer_Consumer_Event_Report, source: NodeID(11), data: [1,1,0,0,0,0,3,0]) // mismatch in last entry
        let piaMatch =   Message(mti:.Producer_Identified_Active, source: NodeID(12), data: [1,1,0,0,0,0,3,3]) // isATrain event

        _ = put.process(pcerMatch, node1)
        _ = put.process(pcerNoMatch, node1)
        _ = put.process(piaMatch, node1)

        XCTAssertEqual(model.roster.count, 2)
        XCTAssertTrue(model.roster.contains( RosterEntry(label: "10", nodeID: NodeID(10), labelSource: .Initial)))
        XCTAssertFalse(model.roster.contains(RosterEntry(label: "11", nodeID: NodeID(11), labelSource: .Initial)))
        XCTAssertTrue(model.roster.contains( RosterEntry(label: "12", nodeID: NodeID(12), labelSource: .Initial)))
    }

    func testSpeedReply() throws {
        let node1 = Node(NodeID(1))
        let model = ThrottleModel(CanLink(localNodeID: NodeID(0)))
        
        let put = ThrottleProcessor(nil, model: model)
        
        // 0 mps test
        let replyMsg0 = Message(mti:.Traction_Control_Reply, source: NodeID(10), destination: NodeID(1), data: [0x10, 0x00, 0x00, 0x00, 0x80, 0x00, 0xFF, 0xFF]) // speed reply
        
        _ = put.process(replyMsg0, node1)
        
        XCTAssertEqual(model.speed, 0.0)
        XCTAssertTrue(model.forward)
        XCTAssertFalse(model.reverse)

        // 100 mps test
        let replyMsg100 = Message(mti:.Traction_Control_Reply, source: NodeID(10), destination: NodeID(1), data: [0x10, 0x51, 0x96, 0x00, 0x80, 0x00, 0xFF, 0xFF]) // speed reply
        
        _ = put.process(replyMsg100, node1)
        
        XCTAssertEqual(round(model.speed), 100.0)
        XCTAssertTrue(model.forward)
        XCTAssertFalse(model.reverse)
        
        // 50 mps test
        let replyMsg50 = Message(mti:.Traction_Control_Reply, source: NodeID(10), destination: NodeID(1), data: [0x10, 0x4D, 0x96, 0x00, 0x80, 0x00, 0xFF, 0xFF]) // speed reply

        _ = put.process(replyMsg50, node1)

        XCTAssertEqual(round(model.speed), 50.0)
        XCTAssertTrue(model.forward)
        XCTAssertFalse(model.reverse)
        
        // reverse 0 mps test
        let replyMsgR0 = Message(mti:.Traction_Control_Reply, source: NodeID(10), destination: NodeID(1), data: [0x10, 0x80, 0x00, 0x00, 0x80, 0x00, 0xFF, 0xFF]) // speed reply
        
        _ = put.process(replyMsgR0, node1)
        
        XCTAssertEqual(model.speed, 0.0)
        XCTAssertTrue(model.reverse)
        XCTAssertFalse(model.forward)

    }

    
}
