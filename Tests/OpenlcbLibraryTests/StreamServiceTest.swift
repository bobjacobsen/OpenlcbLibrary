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
        receivedMemo = StreamService.StreamWriteMemo(nodeId: NodeID(0), sourceStreamNumber: 0x05,
                                                     bufferSize: 0, wholeData:[])
        StreamService.nextProposedDestStreamNumber = 0x05
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    var callback = false
    var failed = true
    
    var totalBytes: Int = -1
    var soFarBytes: Int = -1
    var transferDone = false
    
    var receivedMemo = StreamService.StreamWriteMemo(nodeId: NodeID(0), sourceStreamNumber: 0x05,
                                                 bufferSize: 0, wholeData:[])
    
    func writeCallBackOkCheck(memo : StreamService.StreamWriteMemo) -> () {
        receivedMemo = memo
        callback = true
        failed = false
    }
    func writeCallBackFailCheck(memo : StreamService.StreamWriteMemo, _ : Int) -> () {
        receivedMemo = memo
        callback = true
        failed = true
    }

    func progressCallBackCheck(progress: StreamService.StreamWriteMemo?, totalBytes : Int, soFarBytes : Int, done : Bool) -> () {
        self.totalBytes = totalBytes
        self.soFarBytes = soFarBytes
        self.transferDone = done
    }
    
    func testStreamInitandSendTwiceShortOK() {
        let destId = NodeID(22)
        let sourceStreamID : UInt8 = 0x04

        let streamMemo = StreamService.StreamWriteMemo(nodeId: destId, sourceStreamNumber: sourceStreamID,
                                                       bufferSize: 8192, wholeData:[UInt8](Array(0..<148)),
                                                       okReply : writeCallBackOkCheck,
                                                       rejectedReply : writeCallBackFailCheck,
                                                       progressCallBack: progressCallBackCheck)

        service.createWriteStream(withMemo: streamMemo)

        XCTAssertFalse(callback)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Initiate_Request)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20,0x00, 0x00,0x00, sourceStreamID, 0x00])

        LinkMockLayer.sentMessages = []

        // send a initiate OK reply back
        let destStreamID : UInt8 = 6
        let message1 = Message(mti: .Stream_Initiate_Reply, source: destId, destination: sourceId, data: [0x00,0x80, 0,0, sourceStreamID, destStreamID]) // source 5, dest 6, 128 bytes, code 0
        _ = service.process(message1, Node(NodeID(21)))

        // was good callback called?
        XCTAssertFalse(callback)
        
        guard LinkMockLayer.sentMessages.count == 1 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 1"); return }
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 129)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], destStreamID)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 0)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 1)    // data 2nd
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 2)    // data 3rd
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[128], 127)    // data last

        // check progress was called
        XCTAssertEqual(totalBytes, 148)
        XCTAssertEqual(soFarBytes, 128)
        XCTAssertFalse(transferDone)

        // was good callback called?
        XCTAssertFalse(callback)

        // send a data OK reply back through
        LinkMockLayer.sentMessages = []
 
        let message2 = Message(mti: .Stream_Data_Proceed, source: destId, destination: sourceId, data: [0,0,0,0x80, 0x80,0x00])
        _ = service.process(message2, Node(NodeID(21)))
        
        guard LinkMockLayer.sentMessages.count == 2 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 2"); return }
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 21)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], destStreamID)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 128)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 129)    // data second
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 130)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[20], 147)    // data last

        // also expect end message due to short buffer
        XCTAssertEqual(LinkMockLayer.sentMessages[1].mti, MTI.Stream_Data_Complete)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data.count, 2)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data[0], sourceStreamID)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data[1], destStreamID)    // source stream

        // check progress was called
        XCTAssertEqual(totalBytes, 148)
        XCTAssertEqual(soFarBytes, 148)
        XCTAssertTrue(transferDone)

        // was good callback called?
        XCTAssertTrue(callback)
        XCTAssertFalse(failed)


    }

    func testStreamInitandSendTwiceExactOK() {
        let destId = NodeID(22)
        let sourceStreamID : UInt8 = 0x04
        
        let streamMemo = StreamService.StreamWriteMemo(nodeId: destId, sourceStreamNumber: sourceStreamID,
                                                       bufferSize: 8192, wholeData:[UInt8](Array(0...255)),
                                                       okReply : writeCallBackOkCheck,
                                                       rejectedReply : writeCallBackFailCheck,
                                                       progressCallBack: progressCallBackCheck)
        
        service.createWriteStream(withMemo: streamMemo)
        
        XCTAssertFalse(callback)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Initiate_Request)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20,0x00, 0x00,0x00 , sourceStreamID, 0x00])
        
        LinkMockLayer.sentMessages = []
        
        // send a initiate OK reply back through with dest stream ID 5
        let destStreamID : UInt8 = 6
        let message1 = Message(mti: .Stream_Initiate_Reply, source: destId, destination: sourceId, data: [0x00,0x80, 0,0, sourceStreamID, destStreamID]) // source 5, dest 6, 128 bytes, code 0
        _ = service.process(message1, Node(NodeID(21)))
        
        // was good callback called?
        XCTAssertFalse(callback)
        
        // sending 256 bytes of data, which should be a 128 data byte message followed by a 128 data byte message
        
        guard LinkMockLayer.sentMessages.count == 1 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 1"); return }
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 129)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], destStreamID)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 0)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 1)    // data 2nd
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 2)    // data 3rd
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[128], 127)    // data last
        
        // check progress was called
        XCTAssertEqual(totalBytes, 256)
        XCTAssertEqual(soFarBytes, 128)
        XCTAssertFalse(transferDone)
        
        // send a data OK reply back through
        LinkMockLayer.sentMessages = []
        transferDone = false
        
        let message2 = Message(mti: .Stream_Data_Proceed, source: destId, destination: sourceId, data: [0,0,0,0x80, 0x80,0x00])
        _ = service.process(message2, Node(NodeID(21)))
        
        guard LinkMockLayer.sentMessages.count == 2 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 2"); return }
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 129)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], destStreamID)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 128)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 129)    // data second
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 130)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[128], 255)    // data last
        
        // also expect end message due to short buffer
        XCTAssertEqual(LinkMockLayer.sentMessages[1].mti, MTI.Stream_Data_Complete)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data.count, 2)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data[0], sourceStreamID)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data[1], destStreamID)    // source stream
        
        // check progress was called
        XCTAssertEqual(totalBytes, 256)
        XCTAssertEqual(soFarBytes, 256)
        XCTAssertTrue(transferDone)
        
        
    }
    
    func testStreamInitandSendThriceAndShortOK() {
        let destId = NodeID(22)
        let sourceStreamID : UInt8 = 0x04
        
        var data : [UInt8] = [UInt8](Array(0...255))
        data.append(contentsOf: [UInt8](Array(0...19)) )
        
        let streamMemo = StreamService.StreamWriteMemo(nodeId: destId, sourceStreamNumber: sourceStreamID,
                                                       bufferSize: 8192, wholeData: data,
                                                       okReply : writeCallBackOkCheck,
                                                       rejectedReply : writeCallBackFailCheck,
                                                       progressCallBack: progressCallBackCheck)
        
        service.createWriteStream(withMemo: streamMemo)
        
        XCTAssertFalse(callback)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Initiate_Request)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20,0x00, 0x00,0x00 , sourceStreamID, 0x00])
        
        LinkMockLayer.sentMessages = []
        
        // send a initiate OK reply back through with dest stream ID 5
        let destStreamID : UInt8 = 6
        let message1 = Message(mti: .Stream_Initiate_Reply, source: destId, destination: sourceId, data: [0x00,0x80, 0,0, sourceStreamID, destStreamID]) // source 5, dest 6, 128 bytes, code 0
        _ = service.process(message1, Node(NodeID(21)))
        
        // was good callback called?
        XCTAssertFalse(callback)
        
        // sending 276 bytes of data, which should be two 128 data byte message followed by a 20 data byte message
        
        guard LinkMockLayer.sentMessages.count == 1 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 1"); return }
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 129)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], destStreamID)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 0)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 1)    // data 2nd
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 2)    // data 3rd
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[128], 127)    // data last
        
        // check progress was called
        XCTAssertEqual(totalBytes, 276)
        XCTAssertEqual(soFarBytes, 128)
        XCTAssertFalse(transferDone)
        
        // send a data OK reply back through
        LinkMockLayer.sentMessages = []
        transferDone = false
        
        let message2 = Message(mti: .Stream_Data_Proceed, source: destId, destination: sourceId, data: [0,0,0,0x80, 0x80,0x00])
        _ = service.process(message2, Node(NodeID(21)))
        
        guard LinkMockLayer.sentMessages.count == 1 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 1"); return }
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 129)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], destStreamID)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 128)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 129)    // data second
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 130)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[128], 255)    // data last
                
        // check progress was called
        XCTAssertEqual(totalBytes, 276)
        XCTAssertEqual(soFarBytes, 256)
        XCTAssertFalse(transferDone)
        
        // send a data OK reply back through
        LinkMockLayer.sentMessages = []
        transferDone = false
        
        let message3 = Message(mti: .Stream_Data_Proceed, source: destId, destination: sourceId, data: [0,0,0,0x80, 0x80,0x00])
        _ = service.process(message3, Node(NodeID(21)))
        
        guard LinkMockLayer.sentMessages.count == 2 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 2"); return }
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 21)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], destStreamID)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 0)    // data first - has wrapped
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 1)    // data second
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[3], 2)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[20], 19)    // data last
        
        // also expect end message due to short buffer
        XCTAssertEqual(LinkMockLayer.sentMessages[1].mti, MTI.Stream_Data_Complete)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data.count, 2)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data[0], sourceStreamID)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data[1], destStreamID)    // source stream
        
        // check progress was called
        XCTAssertEqual(totalBytes, 276)
        XCTAssertEqual(soFarBytes, 276)
        XCTAssertTrue(transferDone)
        

    }
    
    func testStreamInitandSendShortOK() {
        let destId = NodeID(22)
        let sourceStreamID : UInt8 = 0x04
        
        let streamMemo = StreamService.StreamWriteMemo(nodeId: destId, sourceStreamNumber: sourceStreamID,
                                                       bufferSize: 8192, wholeData:[UInt8](Array(0..<48)),
                                                       okReply : writeCallBackOkCheck,
                                                       rejectedReply : writeCallBackFailCheck,
                                                       progressCallBack: progressCallBackCheck)
        
        service.createWriteStream(withMemo: streamMemo)

        XCTAssertFalse(callback)
        guard LinkMockLayer.sentMessages.count == 1 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 1"); return }
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Initiate_Request)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20,0x00, 0x00,0x00 , sourceStreamID, 0x00])
        
        LinkMockLayer.sentMessages = []
        
        // send a initiate OK reply back through with dest stream ID 6
        let message1 = Message(mti: .Stream_Initiate_Reply, source: destId, destination: sourceId, data: [0x00,0x80, 0,0, sourceStreamID, 6]) // source 5, dest 6, 128 bytes, code 0
        _ = service.process(message1, Node(NodeID(21)))
        
        // expect in return data and end marker messages
        guard LinkMockLayer.sentMessages.count == 2 else {XCTFail("count = \(LinkMockLayer.sentMessages.count) should be 2"); return }
        
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, MTI.Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data.count, 49)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[0], 6)    // dest stream
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[1], 0)    // data first
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[2], 1)    // data second
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data[48], 47)  // data last

        // Expect end also sent
        XCTAssertEqual(LinkMockLayer.sentMessages[1].mti, MTI.Stream_Data_Complete)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].source, sourceId)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].destination, destId)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data.count, 2)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data[0], sourceStreamID)    // source stream
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data[1], 6)    // dest stream

        // check progress was called
        XCTAssertEqual(totalBytes, 48)
        XCTAssertEqual(soFarBytes, 48)
        XCTAssertTrue(transferDone)

        // was good callback called? Should have been
        XCTAssertTrue(callback)
        XCTAssertFalse(failed)

    }
}
