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
    func receiveListener(msg : Datagram) {received = true}

    func testReceipt() throws {
        received = false
        let msg = Datagram(source : Node(NodeID(12)), destination : Node(NodeID(13)), data : [])
        let receiver  = receiveListener
        let service = DatagramService()
        service.registerDatagramReceivedListener(receiver)
        
        service.fireListeners(msg)
        
        XCTAssertTrue(received)
    }
}
