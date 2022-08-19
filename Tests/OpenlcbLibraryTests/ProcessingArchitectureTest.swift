//
//  ProcessingArchitectureTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

/// Test the system architecture for handling Message Processing. Not intended to fully test the processor, just that
/// they get called in parallel with their real types
///
class ProcessingArchitectureTest: XCTestCase {

    var defaultNode : Node = Node(NodeID(0x05_01_01_01_03_01))
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        defaultNode = Node(NodeID(0x05_01_01_01_03_01))
        defaultNode.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                                  PIP.MEMORY_CONFIGURATION_PROTOCOL,
                                  PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                                  PIP.EVENT_EXCHANGE_PROTOCOL])
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // test of multiple processors working in parallel
    func testMessageArrival() {
        let msg = Message(mti : MTI.Initialization_Complete, source : NodeID(12))
        
        let rnode = Node(NodeID(12))
        let rprocessor : Processor = RemoteNodeProcessor() // track effect of messages on Remote Node
        
        XCTAssertEqual(rnode.state, Node.State.Uninitialized, "node state starts uninitialized")
        rprocessor.process(msg, rnode)
        XCTAssertEqual(rnode.state, Node.State.Initialized, "node state goes initialized")

        let dprocessor : Processor = DatagramProcessor(nil, DatagramService()) // datagram processor doesn't affect node status
        let dnode = Node(NodeID(12))
        dprocessor.process(msg, dnode)
        XCTAssertEqual(dnode.state, Node.State.Uninitialized, "node state should be unchanged")
        
        // printing process, well, prints
        var result : String = ""
        let handler : (_ : String) -> () = { (data: String)  in
            result = data
        }
        let pprocessor : Processor = PrintingProcessor(handler) // example of processor that extracts info from message
        let pnode = Node(NodeID(12))
        pprocessor.process(msg, pnode)
        XCTAssertEqual(result, "00.00.00.00.00.0C: Initialization Complete ")
    }
    
    // test of connecting a CAN link and physical layer
    func testCanLinks() {
        let canPhysicalLayer = CanPhysicalLayer()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        
        // and bring the link up
        canPhysicalLayer.physicalLayerUp()
        
        XCTAssertEqual(canLink.state, CanLink.State.Permitted)
    }
}
