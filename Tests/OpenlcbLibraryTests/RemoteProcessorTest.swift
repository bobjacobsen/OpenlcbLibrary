//
//  RemoteProcessorTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class RemoteProcessorTest: XCTestCase {

    var node21 = Node(NodeID(21))
    let processor : Processor = RemoteNodeProcessor()

    override func setUpWithError() throws {
        node21 = Node(NodeID(21))
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitializationComplete() {
        let msg1 = Message(mti : MTI.InitializationComplete, source : NodeID(12), destination : NodeID(13))
        XCTAssertEqual(node21.state, Node.State.Uninitialized, "node state starts uninitialized")
        processor.process(msg1, node21)
        XCTAssertEqual(node21.state, Node.State.Uninitialized, "node state stays uninitialized")

        let msg2 = Message(mti : MTI.InitializationComplete, source : NodeID(12), destination : NodeID(21))
        XCTAssertEqual(node21.state, Node.State.Uninitialized, "node state starts uninitialized")
        processor.process(msg2, node21)
        XCTAssertEqual(node21.state, Node.State.Initialized, "node state goes initialized")
    }

    func testPipReplyFull() {
        var msg1 = Message(mti : MTI.ProtocolSupportReply, source : NodeID(12), destination : NodeID(13))
        msg1.data = [0x10, 0x10, 0x00, 0x00]
        processor.process(msg1, node21)
        XCTAssertEqual(node21.pipSet, Set([]))

        var msg2 = Message(mti : MTI.ProtocolSupportReply, source : NodeID(12), destination : NodeID(21))
        msg2.data = [0x10, 0x10, 0x00, 0x00]
        processor.process(msg2, node21)
        XCTAssertEqual(node21.pipSet, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL, PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))
    }

    func testPipReply2() {
        var msg1 = Message(mti : MTI.ProtocolSupportReply, source : NodeID(12), destination : NodeID(13))
        msg1.data = [0x10, 0x10]
        processor.process(msg1, node21)
        XCTAssertEqual(node21.pipSet, Set([]))

        var msg2 = Message(mti : MTI.ProtocolSupportReply, source : NodeID(12), destination : NodeID(21))
        msg2.data = [0x10, 0x10]
        processor.process(msg2, node21)
        XCTAssertEqual(node21.pipSet, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL, PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))
    }

    func testPipReplyEmpty() throws {
        var msg = Message(mti : MTI.ProtocolSupportReply, source : NodeID(12), destination : NodeID(13))
        msg.data = []
        processor.process(msg, node21)
        XCTAssertEqual(node21.pipSet, Set([]))
    }

    func testTestsNotComplete() throws {
        // eventually, this will handle all MTI types, but here we check for one not coded yet
        let msg = Message(mti : MTI.ConsumerRangeIdentified, source : NodeID(12), destination : NodeID(13))
        
        processor.process(msg, node21)
    }
}
