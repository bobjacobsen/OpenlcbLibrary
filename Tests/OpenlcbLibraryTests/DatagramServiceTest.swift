//
//  DatagramServiceTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class DatagramServiceTest: XCTestCase {

    class LinkMockLayer : LinkLayer {
        static var sentMessages : [Message] = []
        override func sendMessage( _ message : Message) {
            LinkMockLayer.sentMessages.append(message)
        }
    }
    
    var service = DatagramService(LinkMockLayer(NodeID(12)))
    
    override func setUpWithError() throws {
        service = DatagramService(LinkMockLayer(NodeID(12)))
        LinkMockLayer.sentMessages = []
        received = false
        readMemos = []
        callback = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // test function marks that the listeners were fired
    var received = false
    var readMemos : [DatagramService.DatagramReadMemo] = []
    
    func receiveListener(msg : DatagramService.DatagramReadMemo) -> Bool {
        received = true
        readMemos.append(msg)
        return true
    }

    func testFireListeners() throws {
        let msg = DatagramService.DatagramReadMemo(srcID : NodeID(12), data : [])
        let receiver  = receiveListener
        
        service.registerDatagramReceivedListener(receiver)
        
        service.fireListeners(msg)
        
        XCTAssertTrue(received)
    }
    
    func testWriteMemoEquatable() throws {
        let dm1a = DatagramService.DatagramWriteMemo(destID: NodeID(2), data: [])
        let dm1b = DatagramService.DatagramWriteMemo(destID: NodeID(2), data: [])
        let dm2  = DatagramService.DatagramWriteMemo(destID: NodeID(12), data: [])
        let dm3  = DatagramService.DatagramWriteMemo(destID: NodeID(12), data: [1])
        let dm4  = DatagramService.DatagramWriteMemo(destID: NodeID(12), data: [1,2,3])

        XCTAssertEqual(dm1a, dm1b)
        XCTAssertNotEqual(dm1a, dm2)
        XCTAssertEqual(dm2, dm2)
        XCTAssertNotEqual(dm2, dm3)
        XCTAssertNotEqual(dm2, dm4)
        XCTAssertNotEqual(dm3, dm4)
    }

    func testReadMemoEquatable() throws {
        let dm1a = DatagramService.DatagramReadMemo(srcID: NodeID(1), data: [])
        let dm1b = DatagramService.DatagramReadMemo(srcID: NodeID(1), data: [])
        let dm2  = DatagramService.DatagramReadMemo(srcID: NodeID(11), data: [])
        let dm3  = DatagramService.DatagramReadMemo(srcID: NodeID(11), data: [1])
        let dm4  = DatagramService.DatagramReadMemo(srcID: NodeID(11), data: [1,2,3])
        
        XCTAssertEqual(dm1a, dm1b)
        XCTAssertNotEqual(dm1a, dm2)
        XCTAssertEqual(dm2, dm2)
        XCTAssertNotEqual(dm2, dm3)
        XCTAssertNotEqual(dm2, dm4)
        XCTAssertNotEqual(dm3, dm4)
    }

    func testDatagramType() throws {
        XCTAssertEqual(service.datagramType(data : []), DatagramService.ProtocolID.Unrecognized)
        XCTAssertEqual(service.datagramType(data : [0,2,3]), DatagramService.ProtocolID.Unrecognized)
        
        XCTAssertEqual(service.datagramType(data : [0x20,2,3]), DatagramService.ProtocolID.MemoryOperation)
        
    }

    var callback = false
    func writeCallBackCheck(_ : DatagramService.DatagramWriteMemo, _ : Int) -> () {
        callback = true
    }
    
    func testSendDatagramOK() {
        let writeMemo = DatagramService.DatagramWriteMemo(destID: NodeID(22), data: [0x20, 0x42, 0x30], okReply: writeCallBackCheck)
        
        service.sendDatagram(writeMemo)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        
        // send a reply back through
        let message = Message(mti: .Datagram_Received_OK, source: NodeID(22), destination: NodeID(12))
        _ = service.process(message, Node(NodeID(21)))
        // was callback called?
        XCTAssertTrue(callback)

        // no further messages sent to link
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)

    }

    func testSendThreeDatagramAtOnceOK() {
        let writeMemo = DatagramService.DatagramWriteMemo(destID: NodeID(22), data: [0x20, 0x42, 0x30], okReply: writeCallBackCheck)
        
        service.sendDatagram(writeMemo)
        service.sendDatagram(writeMemo)
        service.sendDatagram(writeMemo)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // only first is send until reply
        
        // send a reply back through
        let message = Message(mti: .Datagram_Received_OK, source: NodeID(22), destination: NodeID(12))
        _ = service.process(message, Node(NodeID(21)))
        // was callback called?
        XCTAssertTrue(callback)
        callback = false
        
        // next should have been sent
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 2)
        // send a reply back through
        _ = service.process(message, Node(NodeID(21)))
        // was callback called?
        XCTAssertTrue(callback)
        callback = false
        
        // next should have been sent
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 3)
        // send a reply back through
        _ = service.process(message, Node(NodeID(21)))
        // was callback called?
        XCTAssertTrue(callback)
        callback = false
        
        // that should be it
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 3)
    }

    func writeCallBackSendAgain(_ : DatagramService.DatagramWriteMemo, _ : Int) -> () {
        callback = true

        let writeMemo = DatagramService.DatagramWriteMemo(destID: NodeID(22), data: [0x20, 0x42, 0x30], okReply: writeCallBackSendAgain)
        service.sendDatagram(writeMemo)
    }

    func testSendThreeDatagramSequentialOK() {
        let writeMemo = DatagramService.DatagramWriteMemo(destID: NodeID(22), data: [0x20, 0x42, 0x30], okReply: writeCallBackSendAgain)
        
        service.sendDatagram(writeMemo)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1) // only first is send until reply
        
        // send a reply back through
        let message = Message(mti: .Datagram_Received_OK, source: NodeID(22), destination: NodeID(12))
        _ = service.process(message, Node(NodeID(21)))
        // was callback called?
        XCTAssertTrue(callback)
        callback = false
        
        // one more should have been sent
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 2)
        // send a reply back through
        _ = service.process(message, Node(NodeID(21)))
        // was callback called?
        XCTAssertTrue(callback)
        callback = false
        
        // one more should have been sent
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 3)
        // send a reply back through
        _ = service.process(message, Node(NodeID(21)))
        // was callback called?
        XCTAssertTrue(callback)
        callback = false
        
        // should have sent one more
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 4)
    }
    
    func testSendDatagramRejected() {
        let writeMemo = DatagramService.DatagramWriteMemo(destID: NodeID(22), data: [0x20, 0x42, 0x30], rejectedReply: writeCallBackCheck)
        
        service.sendDatagram(writeMemo)
        
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
        
        // send a reply back through
        let message = Message(mti: .Datagram_Rejected, source: NodeID(22), destination: NodeID(12), data: [0x80, 0x20])
        _ = service.process(message, Node(NodeID(21)))
        // was callback called?
        XCTAssertTrue(callback)

        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)
    }

    func testReceiveDatagramOK() {
        // set up datagram listener
        let receiver  = receiveListener
        service.registerDatagramReceivedListener(receiver)

        // receive a datagram
        let message = Message(mti: .Datagram, source: NodeID(22), destination: NodeID(12))
        _ = service.process(message, Node(NodeID(21)))
        
        // check that it went through
        XCTAssertTrue(received)
        XCTAssertEqual(readMemos.count, 1)

        service.positiveReplyToDatagram(readMemos[0], flags: 0)
        
        // check message came through
        XCTAssertEqual(LinkMockLayer.sentMessages.count, 1)

    }
}
