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
        // not related to node
        let msg1 = Message(mti : MTI.InitializationComplete, source : NodeID(13))
        XCTAssertEqual(node21.state, Node.State.Uninitialized, "node state starts uninitialized")
        processor.process(msg1, node21)
        XCTAssertEqual(node21.state, Node.State.Uninitialized, "node state stays uninitialized")

        // send by node
        let msg2 = Message(mti : MTI.InitializationComplete, source : NodeID(21))
        XCTAssertEqual(node21.state, Node.State.Uninitialized, "node state starts uninitialized")
        processor.process(msg2, node21)
        XCTAssertEqual(node21.state, Node.State.Initialized, "node state goes initialized")
        
    }

    func testPipReplyFull() {
        let msg1 = Message(mti : MTI.ProtocolSupportReply, source: NodeID(12), destination: NodeID(13), data: [0x10, 0x10, 0x00, 0x00])
        processor.process(msg1, node21)
        XCTAssertEqual(node21.pipSet, Set([]))

        let msg2 = Message(mti : MTI.ProtocolSupportReply, source: NodeID(21), destination: NodeID(12), data: [0x10, 0x10, 0x00, 0x00])
        processor.process(msg2, node21)
        XCTAssertEqual(node21.pipSet, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL, PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))
    }

    func testPipReply2() {
        let msg1 = Message(mti : MTI.ProtocolSupportReply, source: NodeID(12), destination: NodeID(13), data: [0x10, 0x10])
        processor.process(msg1, node21)
        XCTAssertEqual(node21.pipSet, Set([]))

        let msg2 = Message(mti : MTI.ProtocolSupportReply, source: NodeID(21), destination: NodeID(12), data: [0x10, 0x10])
        processor.process(msg2, node21)
        XCTAssertEqual(node21.pipSet, Set([PIP.MEMORY_CONFIGURATION_PROTOCOL, PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL]))
    }

    func testPipReplyEmpty() throws {
        let msg = Message(mti : MTI.ProtocolSupportReply, source: NodeID(12), destination: NodeID(13))
        processor.process(msg, node21)
        XCTAssertEqual(node21.pipSet, Set([]))
    }

    func testLinkDown() throws {
        node21.pipSet = Set([PIP.EVENT_EXCHANGE_PROTOCOL])
        node21.state = .Initialized
        let msg = Message(mti : MTI.LinkLevelDown, source: NodeID(0), destination: NodeID(0))
        processor.process(msg, node21)
        XCTAssertEqual(node21.pipSet, Set([]))
        XCTAssertEqual(node21.state, Node.State.Uninitialized)
    }

    func testLinkUp() throws {
        node21.pipSet = Set([PIP.EVENT_EXCHANGE_PROTOCOL])
        node21.state = .Initialized
        let msg = Message(mti : MTI.LinkLevelUp, source: NodeID(0), destination: NodeID(0))
        processor.process(msg, node21)
        XCTAssertEqual(node21.pipSet, Set([]))
        XCTAssertEqual(node21.state, Node.State.Uninitialized)
    }

    func testUndefinedType() throws {
        var msg = Message(mti : MTI.Unknown, source : NodeID(12), destination: NodeID(13)) // neither to nor from us
        // nothing but logging happens on an unknown type
        processor.process(msg, node21)
        
        msg = Message(mti : MTI.Unknown, source : NodeID(12), destination: NodeID(21)) // to us
        // nothing but logging happens on an unknown type
        processor.process(msg, node21)
    }
    
    func testSnipHandling() throws {
        node21.snip.manufacturerName = "name present"
        
        var msg = Message(mti : MTI.SimpleNodeIdentInfoRequest, source : NodeID(12), destination: NodeID(13))
        processor.process(msg, node21)
        
        // should have cleared SNIP and cache
        XCTAssertEqual(node21.snip.manufacturerName, "")
        
        // add some data
        msg = Message(mti : MTI.SimpleNodeIdentInfoReply, source : NodeID(12), destination: NodeID(13), data: [04,0x31,0x32,0,0,0])
        processor.process(msg, node21)

        XCTAssertEqual(node21.snip.manufacturerName, "12")
    }
    
    
}
