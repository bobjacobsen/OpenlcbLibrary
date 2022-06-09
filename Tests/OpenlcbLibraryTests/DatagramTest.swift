//
//  DatagramTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class DatagramTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitAndEquatable() throws {
        let dg1 = Datagram(source : Node(NodeID(12)), destination : Node(NodeID(13)), data : [1,2,3])
        let dg2 = Datagram(source : Node(NodeID(12)), destination : Node(NodeID(13)), data : [1,2,3])
        let dgdata = Datagram(source : Node(NodeID(12)), destination : Node(NodeID(13)), data : [4,2,3])
        let dgsource = Datagram(source : Node(NodeID(18)), destination : Node(NodeID(13)), data : [1,2,3])
        let dgdestination = Datagram(source : Node(NodeID(12)), destination : Node(NodeID(19)), data : [1,2,3])

        XCTAssertEqual(dg1, dg2)
        XCTAssertNotEqual(dg1, dgdata)
        XCTAssertNotEqual(dg1, dgsource)
        XCTAssertNotEqual(dg1, dgdestination)
    }

    func testDatagramType() throws {
        let dg0 = Datagram(source : Node(NodeID(12)), destination : Node(NodeID(13)), data : [])
        XCTAssertEqual(dg0.datagramType(), Datagram.DatagramProtocolID.Unrecognized)
        let dg1 = Datagram(source : Node(NodeID(12)), destination : Node(NodeID(13)), data : [0,2,3])
        XCTAssertEqual(dg1.datagramType(), Datagram.DatagramProtocolID.Unrecognized)

        let dg2 = Datagram(source : Node(NodeID(12)), destination : Node(NodeID(13)), data : [0x20,2,3])
        XCTAssertEqual(dg2.datagramType(), Datagram.DatagramProtocolID.MemoryOperation)

    }
}
