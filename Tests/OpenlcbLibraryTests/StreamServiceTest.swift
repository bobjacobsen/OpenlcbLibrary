//
//  StreamServiceTest.swift
//  OpenlcbLibrary
//
//  Created by Bob Jacobsen on 1/8/26.
//

import XCTest
@testable import OpenlcbLibrary

final class StreamServiceTest: XCTestCase {

    class LinkMockLayer : LinkLayer {
        static var sentMessages : [Message] = []
        override func sendMessage( _ message : Message) {
            LinkMockLayer.sentMessages.append(message)
        }
    }
    
    let sourceId = NodeID(12)
    var service = StreamService(LinkMockLayer(NodeID(12)))
    // test function marks that the listeners were fired
    var received = false

    override func setUpWithError() throws {
        service = StreamService(LinkMockLayer(sourceId))
        LinkMockLayer.sentMessages = []
        received = false
        callback = false
        receivedMemo = StreamService.StreamWriteUserMemo(sourceStreamNumber: 0xFF,  // a temporary result to tell if overwritten
                                                     destStreamNumber: 0xFF,
                                                     nodeId: NodeID(0), bufferSize: 0)
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    var callback = false
    var failed = true
    
    var receivedMemo = StreamService.StreamWriteUserMemo(sourceStreamNumber: 0xFF,  // a temporary result to avoid Optional
                                                 destStreamNumber: 0xFF,
                                                 nodeId: NodeID(0), bufferSize: 0)
    
    func writeCallBackOkCheck(memo : StreamService.StreamWriteUserMemo) -> () {
        receivedMemo = memo
        callback = true
        failed = false
    }
    func writeCallBackFailCheck(memo : StreamService.StreamWriteUserMemo, _ : Int) -> () {
        receivedMemo = memo
        callback = true
        failed = true
    }

    func testStreamInitandSendTwiceOK() {
        let destId = NodeID(22)
        
        service.createWriteStream(toNode: destId, okReply : writeCallBackOkCheck,
                          rejectedReply : writeCallBackFailCheck)

        XCTAssertFalse(callback)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Initiate_Request)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0, 0, 0x01, 0x00 , 0x00, 0x00])

        // send a initiate OK reply back through with dest stream ID 5
        let destStreamID : UInt8 = 5
        let sourceStreamID : UInt8 = 6
        let message1 = Message(mti: .Stream_Initiate_Reply, source: destId, destination: sourceId, data: [destStreamID, sourceStreamID, 0,0x80, 0x80,0x00]) // dest 5, source 6, 128 bytes, code 0
        _ = service.process(message1, Node(NodeID(21)))

        // was good callback called?
        XCTAssertTrue(callback)
        XCTAssertFalse(failed)
        // no further messages sent to link
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        let memo = receivedMemo
        
        // send 148 bytes of data, which should be a 127 data byte message followed by a 21 data byte message
        LinkMockLayer.sentMessages = []
        
        let data = [UInt8](Array(0...147))
        service.sendStreamData(with: memo, contains: data)

        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 128)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], destStreamID)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 0)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 1)    // data 2nd
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 2)    // data 3rd
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[127], 126)    // data last


        // send a data OK reply back through
        LinkMockLayer.sentMessages = []

        let message2 = Message(mti: .Stream_Data_Proceed, source: destId, destination: sourceId, data: [0,0,0,0x80, 0x80,0x00])
        _ = service.process(message2, Node(NodeID(21)))
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 22)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], 5)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 127)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 128)    // data second
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 129)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[21], 147)    // data last

        // send a data OK reply back through and expect end
        LinkMockLayer.sentMessages = []
        
        _ = service.process(message2, Node(NodeID(21)))
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Complete)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 2)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], 5)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 6)    // source stream

    }

    func testStreamInitandSendShortOK() {
        let destId = NodeID(22)
        
        service.createWriteStream(toNode: destId, okReply : writeCallBackOkCheck,
                                  rejectedReply : writeCallBackFailCheck)
        
        XCTAssertFalse(callback)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Initiate_Request)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0, 0, 0x01, 0x00 , 0x00, 0x00])
        
        // send a initiate OK reply back through with dest stream ID 5
        let message1 = Message(mti: .Stream_Initiate_Reply, source: destId, destination: sourceId, data: [5, 6, 0,0x80, 0x80,0x00]) // dest 5, source 6, 128 bytes, code 0
        _ = service.process(message1, Node(NodeID(21)))
        
        // was good callback called?
        XCTAssertTrue(callback)
        XCTAssertFalse(failed)
        // no further messages sent to link
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        let memo = receivedMemo
        
        // send 48 bytes of data, which go in single message
        LinkMockLayer.sentMessages = []
        
        let data = [UInt8](Array(0...47))
        service.sendStreamData(with: memo, contains: data)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 49)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], 5)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 0)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 1)    // data second
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[48], 47)    // data last

        // send a data OK reply back through and expect end
        LinkMockLayer.sentMessages = []
        
        let message2 = Message(mti: .Stream_Data_Proceed, source: destId, destination: sourceId, data: [0,0,0,0x80, 0x80,0x00])
        _ = service.process(message2, Node(NodeID(21)))
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Complete)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 2)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], 5)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 6)    // source stream

    }
}
