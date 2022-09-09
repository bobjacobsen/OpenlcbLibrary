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

    func testArrayToString() {
        var sut = service.arrayToString(data: [0x41,0x42,0x43,0x44], length: 4)
        XCTAssertEqual(sut, "ABCD")

        sut = service.arrayToString(data: [0x41,0x42,0,0x44], length: 4)
        XCTAssertEqual(sut, "AB")

        sut = service.arrayToString(data: [0x41,0x42,0x43,0x44], length: 2)
        XCTAssertEqual(sut, "AB")

        sut = service.arrayToString(data: [0x41,0x42,0x43,0], length: 4)
        XCTAssertEqual(sut, "ABC")

        sut = service.arrayToString(data: [0x41,0x42,0x43,0x44], length: 8)
        XCTAssertEqual(sut, "ABCD")
    }
    
    func testStringToArray() {
        var aut = service.stringToArray(value: "ABCD", length: 4)
        XCTAssertEqual(aut, [0x41, 0x42, 0x43, 0x44])
        
        aut = service.stringToArray(value: "ABCD", length: 2)
        XCTAssertEqual(aut, [0x41, 0x42])

        aut = service.stringToArray(value: "ABCD", length: 6)
        XCTAssertEqual(aut, [0x41, 0x42, 0x43, 0x44])
    }
    
    func testSpaceDecode() {
        var byte6 = false
        var space : UInt8 = 0x00
        
        (byte6, space) = service.spaceDecode(space: 0xF8)
        XCTAssertEqual(space, 0xF8)
        XCTAssertTrue(byte6)

        (byte6, space) = service.spaceDecode(space: 0xFF)
        XCTAssertEqual(space, 0x03)
        XCTAssertFalse(byte6)

        (byte6, space) = service.spaceDecode(space: 0xFD)
        XCTAssertEqual(space, 0x01)
        XCTAssertFalse(byte6)
    }
}
