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
    
    let node12 = Node(NodeID(12))
    var dService : DatagramService = DatagramService(LinkMockLayer(NodeID(12)))
    var sService : StreamService = StreamService(LinkMockLayer(NodeID(12)))
    var mService : MemoryService = MemoryService(dservice: DatagramService(LinkMockLayer(NodeID(12))))  // have to init with something, will overwrite in setUpWithError

    var returnedMemoryReadMemo : [MemoryService.MemoryReadMemo] = []
    func callbackR(memo : MemoryService.MemoryReadMemo) {
        returnedMemoryReadMemo.append(memo)
    }
    
    var returnedMemoryWriteMemo : [MemoryService.MemoryWriteMemo] = []
    func callbackW(memo : MemoryService.MemoryWriteMemo) {
        returnedMemoryWriteMemo.append(memo)
    }

    func callbackP(memo : MemoryService.MemoryWriteMemo, totalLength : Int, bytesSoFar : Int) {
        self.totalLength = totalLength
        self.bytesSoFar  = bytesSoFar
    }

    var totalLength = -1    // for progress reply
    var bytesSoFar  = -1
    
    override func setUpWithError() throws {
        LinkMockLayer.sentMessages = []
        returnedMemoryReadMemo = []
        returnedMemoryWriteMemo = []
        let linkMockLayer = LinkMockLayer(NodeID(12))
        dService = DatagramService(linkMockLayer)
        sService = StreamService(linkMockLayer)
        mService = MemoryService(dservice: dService, sservice: sService)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSingleRead() throws {
        let memMemo = MemoryService.MemoryReadMemo(nodeID: NodeID(123), size: 64, space: 0xFD, address: 0,
                                                   rejectedReply: callbackR, dataReply: callbackR)
        mService.requestMemoryRead(memMemo)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        
        // have to reply through DatagramService
        _ = dService.process(Message(mti:.Datagram_Received_OK, source: NodeID(123), destination: NodeID(12)), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20, 0x41, 0,0,0,0, 64])
        XCTAssertEqual(returnedMemoryReadMemo.count, 0) // no memory read op returned
        
        _ = dService.process(Message(mti:.Datagram, source: NodeID(123), destination: NodeID(12), data:  [0x20, 0x51, 0,0,0,0, 1,2,3,4]), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 2) // read reply datagram reply sent
        XCTAssertEqual(returnedMemoryReadMemo.count, 1) // memory read returned
        
    }
    
    func testSingleWriteReply() throws {
        let memMemo = MemoryService.MemoryWriteMemo(nodeID: NodeID(123),
                                                    okReply: callbackW, rejectedReply: callbackW,
                                                    size: 64, space: 0xFD, address: 0,
                                                    data: [1,2,3])
        mService.requestMemoryWrite(memMemo)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        
        // have to reply through DatagramService
        _ = dService.process(Message(mti:.Datagram_Received_OK, source: NodeID(123), destination: NodeID(12), data:[0x80]), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20, 0x01, 0,0,0,0, 1,2,3])
        XCTAssertEqual(returnedMemoryWriteMemo.count, 0) // no memory write op returned, waiting for reply datagram
        
        _ = dService.process(Message(mti:.Datagram, source: NodeID(123), destination: NodeID(12), data:  [0x20, 0x11, 0,0,0,0]), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 2) // write reply datagram reply sent
        XCTAssertEqual(returnedMemoryWriteMemo.count, 1) // memory write returned
        
    }
 
    func testSingleWriteNoReply() throws {
        let memMemo = MemoryService.MemoryWriteMemo(nodeID: NodeID(123),
                                                    okReply: callbackW, rejectedReply: callbackW,
                                                    size: 64, space: 0xFD, address: 0,
                                                    data: [1,2,3])
        mService.requestMemoryWrite(memMemo)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        
        // datagram OK reply says no following message
        _ = dService.process(Message(mti:.Datagram_Received_OK, source: NodeID(123), destination: NodeID(12), data:[0x00]), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20, 0x01, 0,0,0,0, 1,2,3])
        XCTAssertEqual(returnedMemoryWriteMemo.count, 1) // memory write op returns immediately
        
    }

    func testMultipleRead() throws {

        // make three requests, only one of which should go forward at a time
        let memMemo0 = MemoryService.MemoryReadMemo(nodeID: NodeID(123), size: 64, space: 0xFD, address: 0,
                                                   rejectedReply: callbackR, dataReply: callbackR)
        mService.requestMemoryRead(memMemo0)
        let memMemo64 = MemoryService.MemoryReadMemo(nodeID: NodeID(123), size: 32, space: 0xFD, address: 64,
                                                    rejectedReply: callbackR, dataReply: callbackR)
        mService.requestMemoryRead(memMemo64)
        let memMemo128 = MemoryService.MemoryReadMemo(nodeID: NodeID(123), size: 16, space: 0xFD, address: 128,
                                                    rejectedReply: callbackR, dataReply: callbackR)
        mService.requestMemoryRead(memMemo128)

        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // only one memory request datagram sent

        // have to reply through DatagramService
        _ = dService.process(Message(mti:.Datagram_Received_OK, source: NodeID(123), destination: NodeID(12)), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20, 0x41, 0,0,0,0, 64])
        XCTAssertEqual(returnedMemoryReadMemo.count, 0) // no memory read op returned

        _ = dService.process(Message(mti:.Datagram, source: NodeID(123), destination: NodeID(12), data:  [0x20, 0x51, 0,0,0,0, 1,2,3,4]), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 3) // read reply datagram reply sent and next datagram sent
        XCTAssertEqual(returnedMemoryReadMemo.count, 1) // memory read returned
        
        // walk through 2nd datagram
        _ = dService.process(Message(mti:.Datagram_Received_OK, source: NodeID(123), destination: NodeID(12)), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 3) // memory request datagram sent
        XCTAssertEqual(LinkMockLayer.sentMessages[2].data, [0x20, 0x41, 0,0,0,64, 32])
        XCTAssertEqual(returnedMemoryReadMemo.count, 1) // no memory read op returned
        
        _ = dService.process(Message(mti:.Datagram, source: NodeID(123), destination: NodeID(12), data:  [0x20, 0x51, 0,0,0,64, 1,2,3,4]), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 5) // read reply datagram reply sent and next datagram sent
        XCTAssertEqual(returnedMemoryReadMemo.count, 2) // memory read returned
}

    func testSingleWriteStream() throws {
        let memMemo = MemoryService.MemoryWriteMemo(nodeID: NodeID(123),
                                                    okReply: callbackW, rejectedReply: callbackW,
                                                    progressReply: callbackP,
                                                    size: 64, space: 0xEF, address: 0,
                                                    data: [1,2,3])
        mService.requestMemoryWriteStream(memMemo)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        
        let sourceStream : UInt8 = 0x04
        let destStream : UInt8 = 0x06

        // provide datagram received OK
        let msg1 = Message(mti:.Datagram_Received_OK, source: NodeID(123), destination: NodeID(12), data:[0x80])
        _ = dService.process(msg1, node12)
        _ = sService.process(msg1, node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory write stream datagram sent
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20, 0x20, 0,0,0,0, 0xEF, sourceStream])
        XCTAssertEqual(returnedMemoryWriteMemo.count, 0) // no memory write op returned, waiting for end of stream

        LinkMockLayer.sentMessages = [] // reset counts
        totalLength = -1
        bytesSoFar  = -1
        
        // provide write reply datagram
        let msg2 = Message(mti:.Datagram, source: NodeID(123), destination: NodeID(12), data:  [0x20, 0x30, 0,0,0,0, 0xEF, sourceStream, destStream])
        _ = dService.process(msg2, node12)
        _ = sService.process(msg2, node12)

        XCTAssertEqual(returnedMemoryWriteMemo.count, 0) // no memory write op returned, waiting for end of stream
        XCTAssertEqual(totalLength, -1) // no progress reply yet
        XCTAssertEqual(bytesSoFar, -1) // no progress reply yet

        XCTAssertEqual(LinkMockLayer.sentMessages.count, 2) // write reply datagram reply and stream init message sent
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, .Datagram_Received_OK)
        
        guard LinkMockLayer.sentMessages.count >= 2 else { XCTFail(); return } // to prevent test crashing in tests below
        XCTAssertEqual(LinkMockLayer.sentMessages[1].mti, .Stream_Initiate_Request)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data, [0x20,0x00, 0x00,0x00,  sourceStream, 0])
        
        LinkMockLayer.sentMessages = [] // reset counts
        totalLength = -1
        bytesSoFar  = -1

        // provide stream init reply messsage
        let msg3 = Message(mti:.Stream_Initiate_Reply, source: NodeID(123), destination: NodeID(12), data:  [0x10,0x00, 0x00,0x00, sourceStream, destStream])
        _ = dService.process(msg3, node12)
        _ = sService.process(msg3, node12)

        XCTAssertEqual(LinkMockLayer.sentMessages.count, 2) // stream data, stream end
        guard LinkMockLayer.sentMessages.count >= 1 else { XCTFail(); return } // to prevent test crashing in tests below
        XCTAssertEqual(LinkMockLayer.sentMessages[0].mti, .Stream_Data_Send)
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [destStream, 1,2,3]) // source stream 5, dest stream 6
        guard LinkMockLayer.sentMessages.count >= 2 else { XCTFail(); return } // to prevent test crashing in tests below
        XCTAssertEqual(LinkMockLayer.sentMessages[1].mti, .Stream_Data_Complete)
        XCTAssertEqual(LinkMockLayer.sentMessages[1].data, [sourceStream, destStream])

        XCTAssertEqual(totalLength, 3) // all data
        XCTAssertEqual(bytesSoFar, 3) // sent
        XCTAssertEqual(returnedMemoryWriteMemo.count, 1) // memory write complete

    }
    

    
    
    func testArrayToString() {
        var sut = mService.arrayToString(data: [0x41,0x42,0x43,0x44], length: 4)
        XCTAssertEqual(sut, "ABCD")

        sut = mService.arrayToString(data: [0x41,0x42,0,0x44], length: 4)
        XCTAssertEqual(sut, "AB")

        sut = mService.arrayToString(data: [0x41,0x42,0x43,0x44], length: 2)
        XCTAssertEqual(sut, "AB")

        sut = mService.arrayToString(data: [0x41,0x42,0x43,0], length: 4)
        XCTAssertEqual(sut, "ABC")

        sut = mService.arrayToString(data: [0x41,0x42,0x43,0x44], length: 8)
        XCTAssertEqual(sut, "ABCD")
    }
    
    func testStringToArray() {
        var aut = mService.stringToArray(value: "ABCD", length: 4)
        XCTAssertEqual(aut, [0x41, 0x42, 0x43, 0x44])
        
        aut = mService.stringToArray(value: "ABCD", length: 2)
        XCTAssertEqual(aut, [0x41, 0x42])

        aut = mService.stringToArray(value: "ABCD", length: 6)
        XCTAssertEqual(aut, [0x41, 0x42, 0x43, 0x44, 0x00, 0x00])
    }
    
    func testSpaceDecode() {
        var byte6 = false
        var space : UInt8 = 0x00
        
        (byte6, space) = mService.spaceDecode(space: 0xF8)
        XCTAssertEqual(space, 0xF8)
        XCTAssertTrue(byte6)

        (byte6, space) = mService.spaceDecode(space: 0xFF)
        XCTAssertEqual(space, 0x03)
        XCTAssertFalse(byte6)

        (byte6, space) = mService.spaceDecode(space: 0xFD)
        XCTAssertEqual(space, 0x01)
        XCTAssertFalse(byte6)
    }
    
    
}
