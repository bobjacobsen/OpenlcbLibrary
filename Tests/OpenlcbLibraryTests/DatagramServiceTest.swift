//
//  DatagramServiceTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class DatagramServiceTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // test function marks that the listeners were fired
    var received = false
    func receiveListener(msg : DatagramService.DatagramReadMemo) {received = true}

    func testFireListeners() throws {
        received = false
        let msg = DatagramService.DatagramReadMemo(srcID : NodeID(12), destID : NodeID(13), data : [])
        let receiver  = receiveListener
        let service = DatagramService()
        service.registerDatagramReceivedListener(receiver)
        
        service.fireListeners(msg)
        
        XCTAssertTrue(received)
    }
    
    func testMemoEquatable() throws {
        let dm1a = DatagramService.DatagramWriteMemo(srcID: NodeID(1), destID: NodeID(2), data: [])
        let dm1b = DatagramService.DatagramWriteMemo(srcID: NodeID(1), destID: NodeID(2), data: [])
        let dm2  = DatagramService.DatagramWriteMemo(srcID: NodeID(11), destID: NodeID(12), data: [])
        let dm3  = DatagramService.DatagramWriteMemo(srcID: NodeID(11), destID: NodeID(12), data: [1])
        let dm4  = DatagramService.DatagramWriteMemo(srcID: NodeID(11), destID: NodeID(12), data: [1,2,3])

        XCTAssertEqual(dm1a, dm1b)
        XCTAssertNotEqual(dm1a, dm2)
        XCTAssertEqual(dm2, dm2)
        XCTAssertNotEqual(dm2, dm3)
        XCTAssertNotEqual(dm2, dm4)
        XCTAssertNotEqual(dm3, dm4)
    }

    func testDatagramType() throws {
        let service = DatagramService()
        
        XCTAssertEqual(service.datagramType(data : []), DatagramService.DatagramProtocolID.Unrecognized)
        XCTAssertEqual(service.datagramType(data : [0,2,3]), DatagramService.DatagramProtocolID.Unrecognized)
        
        XCTAssertEqual(service.datagramType(data : [0x20,2,3]), DatagramService.DatagramProtocolID.MemoryOperation)
        
    }

    
}
