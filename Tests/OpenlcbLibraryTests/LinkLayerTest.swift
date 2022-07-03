//
//  LinkLayerTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class LinkLayerTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // test function marks that the listeners were fired
    var received = false
    func receiveListener(msg : Message) {received = true}

    func testReceipt() throws {
        received = false
        let msg = Message(mti : MTI.Initialization_Complete, source : NodeID(12), destination : NodeID(21))
        let receiver  = receiveListener
        let layer = LinkLayer()
        layer.registerMessageReceivedListener(receiver)
        
        layer.fireListeners(msg)
        
        XCTAssertTrue(received)
    }

}
