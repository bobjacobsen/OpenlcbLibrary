//
//  ProcessorTest.swift
//  
//
//  Created by Bob Jacobsen on 8/18/22.
//

import XCTest
@testable import OpenlcbLibrary

final class ProcessorTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    struct TestStruct : Processor {
        func process(_ message: Message, _ node: Node)  -> Bool {
            return false
        }
    }
    
    func testCheckSrcID() throws {
        let node1 = Node(NodeID(1))
        let node2 = Node(NodeID(2))
        
        let messageFrom1 = Message(mti: .Verified_NodeID, source: NodeID(1))
        
        let put = TestStruct()
        
        XCTAssertTrue(put.checkSourceID(messageFrom1, node1))
        XCTAssertFalse(put.checkSourceID(messageFrom1, node2))
    }

    func testCheckDestID() throws {
        let node1 = Node(NodeID(1))
        let node2 = Node(NodeID(2))
        
        let globalMessage = Message(mti: .Verified_NodeID, source: NodeID(1))
        let addressedMessage = Message(mti: .Datagram, source: NodeID(1), destination: NodeID(2))
        
        let put = TestStruct()
        
        XCTAssertFalse(put.checkDestID(globalMessage, node1))
        XCTAssertTrue(put.checkDestID(addressedMessage, node2))
        XCTAssertFalse(put.checkDestID(globalMessage, node1))
    }
}

