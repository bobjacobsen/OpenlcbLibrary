//
//  MemoryServiceTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class MemoryServiceTest: XCTestCase {

    class LinkMockLayer : LinkLayer {
        static var sentMessages : [Message] = []
        override func sendMessage( _ message : Message) {
            LinkMockLayer.sentMessages.append(message)
        }
    }
    
    var service : MemoryService = MemoryService(service: DatagramService(LinkMockLayer(NodeID(12))))
    
    func callback(memo : MemoryService.MemoryReadMemo) {
    }
    
    override func setUpWithError() throws {
        LinkMockLayer.sentMessages = []
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRead() throws {
        let memMemo = MemoryService.MemoryReadMemo(nodeID: NodeID(123), size: 64, space: 0xFD, address: 0,
                                                   rejectedReply: callback, dataReply: callback)
        service.requestMemoryRead(memMemo)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
    }

}
