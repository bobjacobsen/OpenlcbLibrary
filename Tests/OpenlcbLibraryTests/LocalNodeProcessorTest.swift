//
//  LocalNodeProcessorTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class LocalNodeProcessorTest: XCTestCase {

    var node21 = Node(NodeID(21))
    let processor : Processor = LocalNodeProcessor(LinkMockLayer())
    

    class LinkMockLayer : LinkLayer {
        static var sentMessages : [Message] = []
        override func sendMessage( _ message : Message) {
            LinkMockLayer.sentMessages.append(message)
        }
    }

    override func setUpWithError() throws {
        node21 = Node(NodeID(21))
        LinkMockLayer.sentMessages = []
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testLinkUp() throws {
        node21.state = .Uninitialized
        let msg = Message(mti : MTI.Link_Level_Up, source : NodeID(0), destination : NodeID(0), data: [])

        processor.process(msg, node21)

        XCTAssertEqual(node21.state, Node.State.Initialized)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 2)
        XCTAssertEqual(LinkMockLayer.sentMessages[0],
                       Message(mti: MTI.Initialization_Complete, source: node21.id, data: node21.id.toArray()))
        XCTAssertEqual(LinkMockLayer.sentMessages[1],
                       Message(mti: MTI.Verify_NodeID_Number_Global, source: node21.id))

    }

    func testLinkDown() throws {
        node21.state = .Initialized
        let msg = Message(mti : MTI.Link_Level_Down, source : NodeID(0), destination : NodeID(0), data: [])

        processor.process(msg, node21)

        XCTAssertEqual(node21.state, Node.State.Uninitialized)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 0)

    }

    func testVerifyGlobal() {
        // not related to node
        let msg1 = Message(mti : MTI.Verify_NodeID_Number_Global, source : NodeID(13), data: [0,0,0,0,12,21])
        processor.process(msg1, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 0)

        // global no node ID
        let msg2 = Message(mti : MTI.Verify_NodeID_Number_Global, source : NodeID(13))
        processor.process(msg2, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        LinkMockLayer.sentMessages = []
        
        // global this Node ID
        let msg3 = Message(mti : MTI.Verify_NodeID_Number_Global, source : NodeID(13), data: [0,0,0,0,0,21])
        processor.process(msg3, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
    }

    func testVerifyAddressed() {
        // not related to node
        let msg1 = Message(mti : MTI.Verify_NodeID_Number_Addressed, source : NodeID(13), destination : NodeID(24), data: [0,0,0,0,0,24])
        processor.process(msg1, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 0)

        // addressed no node ID
        let msg2 = Message(mti : MTI.Verify_NodeID_Number_Addressed, source : NodeID(13), destination : NodeID(21))
        processor.process(msg2, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        LinkMockLayer.sentMessages = []
        
        // addressed this Node ID
        let msg3 = Message(mti : MTI.Verify_NodeID_Number_Addressed, source : NodeID(13), destination : NodeID(21), data: [0,0,0,0,0,21])
        processor.process(msg3, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
    }

    func testPip() {
        node21.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                             PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                             PIP.EVENT_EXCHANGE_PROTOCOL])

        // not related to node
        let msg1 = Message(mti : MTI.Protocol_Support_Inquiry, source : NodeID(13), destination : NodeID(24))
        processor.process(msg1, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 0)

        // addressed to node
        let msg2 = Message(mti : MTI.Protocol_Support_Inquiry, source : NodeID(13), destination : NodeID(21))
        processor.process(msg2, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x44,0x10,0x00, 0x00, 0x00, 0x00])
 }

    func testSnip() {
        node21.snip.manufacturerName = "Sample Nodes"
        node21.snip.modelName        = "Node 1"
        node21.snip.hardwareVersion  = "HVersion 1"
        node21.snip.softwareVersion  = "SVersion 1"
        node21.snip.updateSnipDataFromStrings()

        // not related to node
        let msg1 = Message(mti : MTI.Simple_Node_Ident_Info_Request, source : NodeID(13), destination : NodeID(24))
        processor.process(msg1, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 0)

        // addressed to node
        let msg2 = Message(mti : MTI.Simple_Node_Ident_Info_Request, source : NodeID(13), destination : NodeID(21))
        processor.process(msg2, node21)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0...2], [0x04,0x53,0x61])
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 46)
    }
    
    func testIdentifyEventsAddressed() {
        // addressed to node
        let msg2 = Message(mti : MTI.Identify_Events_Addressed, source : NodeID(13), destination : NodeID(21))
        processor.process(msg2, node21)

        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Optional_Interaction_Rejected)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 4)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x10, 0x43, 0x09, 0x68])

    }
    
    func testUnsupportedMessageGlobal() {
        // global, testing with an MTI we don't understand
        let msg1 = Message(mti : MTI.Identify_Producer, source : NodeID(13))
        processor.process(msg1, node21)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 0)
    }
        
    func testUnsupportedMessageAddressed() {
        // addressed to node, testing with an MTI we don't understand
        let msg2 = Message(mti : MTI.Remote_Button_Request, source : NodeID(13), destination : NodeID(21))
        processor.process(msg2, node21)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Optional_Interaction_Rejected)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 4)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x10, 0x43, 0x09, 0x48])  // error code, MTI
        
    }

    func testDontRejectOIR() {
        let msg1 = Message(mti : MTI.Optional_Interaction_Rejected, source : NodeID(13), destination : NodeID(21))
        processor.process(msg1, node21)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 0)
    }
 
    func testDontRejectTDE() {
        let msg1 = Message(mti : MTI.Terminate_Due_To_Error, source : NodeID(13), destination : NodeID(21))
        processor.process(msg1, node21)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 0)
    }

}
