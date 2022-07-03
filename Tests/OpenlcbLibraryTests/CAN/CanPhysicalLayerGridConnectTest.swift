//
//  CanPhysicalLayerGridConnectTest.swift
//  
//
//  Created by Bob Jacobsen on 6/14/22.
//

import XCTest
@testable import OpenlcbLibrary

class CanPhysicalLayerGridConnectTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        capturedString = "<none>"
        receivedFrames = []
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // PHY side
    var capturedString = ""
    func captureString(string : String) {
        capturedString = string
    }
    
    // Link Layer side
    var receivedFrames : [CanFrame] = []
    func receiveListener(frame : CanFrame) {receivedFrames+=[frame]}

    
    func testCID4Sent() {
        let gc = CanPhysicalLayerGridConnect(callback: captureString)

        gc.sendCanFrame(CanFrame(cid:4, nodeID: NodeID(0x010203040506), alias: 0xABC))
        XCTAssertEqual(capturedString, ":X14506ABCN;\n")
    }
    
    func testVerifyNodeSent() {
        let gc = CanPhysicalLayerGridConnect(callback: captureString)
        
        gc.sendCanFrame(CanFrame(control:0x19170, alias:0x365, data: [0x02, 0x01, 0x12, 0xFE, 0x05, 0x6C]))
        XCTAssertEqual(capturedString, ":X19170365N020112FE056C;\n")
    }
    
    func testOneFrameReceivedExactlyHeaderOnly() {
        let gc = CanPhysicalLayerGridConnect(callback: captureString)
        gc.registerFrameReceivedListener(receiveListener)
        let bytes : [UInt8] = [0x3a, 0x58, 0x31, 0x39, 0x34, 0x39, 0x30, 0x33, 0x36, 0x35, 0x4e, 0x3b, 0x0a] // :X19490365N;
        
        gc.receiveChars(data: bytes)
        
        XCTAssertEqual(receivedFrames[0], CanFrame(header: 0x19490365, data:[]))
    }

    func testOneFrameReceivedExactlyWithData() {
        let gc = CanPhysicalLayerGridConnect(callback: captureString)
        gc.registerFrameReceivedListener(receiveListener)
        let bytes : [UInt8] = [0x3a, 0x58, 0x31, 0x39, 0x31, 0x42, 0x30, 0x33, 0x36, 0x35, 0x4e, 0x30,
                               0x32, 0x30, 0x31, 0x31, 0x32, 0x46, 0x45, 0x30, 0x35, 0x36, 0x43, 0x3b]
                                // :X19170365N020112FE056C;
        
        gc.receiveChars(data: bytes)
        
        XCTAssertEqual(receivedFrames[0], CanFrame(header: 0x191B0365, data:[0x02, 0x01, 0x12, 0xFE, 0x05, 0x6C]))
    }

    func testOneFrameReceivedHeaderOnlyTwice() {
        let gc = CanPhysicalLayerGridConnect(callback: captureString)
        gc.registerFrameReceivedListener(receiveListener)
        let bytes : [UInt8] = [0x3a, 0x58, 0x31, 0x39, 0x34, 0x39, 0x30, 0x33, 0x36, 0x35, 0x4e, 0x3b, 0x0a] // :X19490365N;
        
        gc.receiveChars(data: bytes+bytes)

        XCTAssertEqual(receivedFrames[0], CanFrame(header: 0x19490365, data:[]))
        XCTAssertEqual(receivedFrames[1], CanFrame(header: 0x19490365, data:[]))
    }

    func testOneFrameReceivedInTwoChunks() {
        let gc = CanPhysicalLayerGridConnect(callback: captureString)
        gc.registerFrameReceivedListener(receiveListener)
        let bytes1 : [UInt8] = [0x3a, 0x58, 0x31, 0x39, 0x31, 0x37, 0x30, 0x33, 0x36, 0x35, 0x4e, 0x30]
                                // :X19170365N020112FE056C;
        
        gc.receiveChars(data: bytes1)
        
        let bytes2 : [UInt8] = [0x32, 0x30, 0x31, 0x31, 0x32, 0x46, 0x45, 0x30, 0x35, 0x36, 0x43, 0x3b]
        gc.receiveChars(data: bytes2)

        XCTAssertEqual(receivedFrames[0], CanFrame(header: 0x19170365, data:[0x02, 0x01, 0x12, 0xFE, 0x05, 0x6C]))
    }
    
    func testSequence() {
        let gc = CanPhysicalLayerGridConnect(callback: captureString)
        gc.registerFrameReceivedListener(receiveListener)
        let bytes : [UInt8] = [0x3a, 0x58, 0x31, 0x39, 0x34, 0x39, 0x30, 0x33, 0x36, 0x35, 0x4e, 0x3b, 0x0a] // :X19490365N;
        
        gc.receiveChars(data: bytes)

        XCTAssertEqual(receivedFrames.count, 1)
        XCTAssertEqual(receivedFrames[0], CanFrame(header: 0x19490365, data:[]))
        receivedFrames = []
        
        gc.receiveChars(data: bytes)
        XCTAssertEqual(receivedFrames.count, 1)
        XCTAssertEqual(receivedFrames[0], CanFrame(header: 0x19490365, data:[]))

    }
}
