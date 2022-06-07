//
//  CanSerialPhysicalLayer.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class CanPhysicalLayerTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // test function marks that the listeners were fired
    var received = false
    func receiveListener(frame : CanFrame) {received = true}

    func testReceipt() throws {
        received = false
        let frame = CanFrame(header: 0x000, data: [])
        let receiver  = receiveListener
        let layer = CanPhysicalLayer()
        layer.registerFrameReceivedListener(receiver)
        
        layer.fireListeners(frame)
        
        XCTAssertTrue(received)
    }
}
