//
//  DatagramProcessorTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary
class DatagramProcessorTest: XCTestCase {

    let processor : Processor = DatagramProcessor(nil, DatagramService())
    var node = Node(NodeID(12))

    override func setUpWithError() throws {
        node = Node(NodeID(12))
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitializationComplete() {
        let msg = Message(mti : MTI.Initialization_Complete, source : NodeID(12), destination : NodeID(13))
        // datagram processor doesn't affect node status
        processor.process(msg, node)
        
        XCTAssertEqual(node.state, Node.State.Uninitialized, "node state should be unchanged")
    }

    func testTestsNptComplete() {
        // eventually, this will handle all MTI types, but here we check for one not coded yet
        let msg = Message(mti : MTI.Consumer_Range_Identified, source : NodeID(12), destination : NodeID(13))
        
        processor.process(msg, node)
    }

}
