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
    var mService : MemoryService = MemoryService(service: DatagramService(LinkMockLayer(NodeID(12))))

    var returnedMemoryReadMemo : [MemoryService.MemoryReadMemo] = []
    func callbackR(memo : MemoryService.MemoryReadMemo) {
        returnedMemoryReadMemo.append(memo)
    }
    
    var returnedMemoryWriteMemo : [MemoryService.MemoryWriteMemo] = []
    func callbackW(memo : MemoryService.MemoryWriteMemo) {
        returnedMemoryWriteMemo.append(memo)
    }
    
    override func setUpWithError() throws {
        LinkMockLayer.sentMessages = []
        returnedMemoryReadMemo = []
        returnedMemoryWriteMemo = []
        dService = DatagramService(LinkMockLayer(NodeID(12)))
        mService = MemoryService(service: dService)
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
    
    func testSingleWrite() throws {
        let memMemo = MemoryService.MemoryWriteMemo(nodeID: NodeID(123),
                                                    okReply: callbackW, rejectedReply: callbackW,
                                                    size: 64, space: 0xFD, address: 0,
                                                    data: [1,2,3])
        mService.requestMemoryWrite(memMemo)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        
        // have to reply through DatagramService
        _ = dService.process(Message(mti:.Datagram_Received_OK, source: NodeID(123), destination: NodeID(12)), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // memory request datagram sent
        XCTAssertEqual(LinkMockLayer.sentMessages[0].data, [0x20, 0x01, 0,0,0,0, 1,2,3])
        XCTAssertEqual(returnedMemoryWriteMemo.count, 0) // no memory write op returned
        
        _ = dService.process(Message(mti:.Datagram, source: NodeID(123), destination: NodeID(12), data:  [0x20, 0x11, 0,0,0,0]), node12)
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 2) // write reply datagram reply sent
        XCTAssertEqual(returnedMemoryWriteMemo.count, 1) // memory write returned
        
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
