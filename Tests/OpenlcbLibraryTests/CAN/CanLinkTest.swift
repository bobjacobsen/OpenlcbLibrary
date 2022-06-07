//
//  PhysicalLinkTest.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class CanLinkTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Mock CanPhysicalLayer to record frames requested to be sent
    class CanMockPhysicalLayer : CanPhysicalLayer {
        var receivedFrames : [CanFrame] = []
        override func sendCanFrame(_ frame : CanFrame) { receivedFrames.append(frame) }
    }
    /// Mock Message to record messages requested to be sent
    class MessageMockLayer {
        var receivedMessages : [Message] = []
        func receiveMessage(_ msg : Message) { receivedMessages.append(msg) }
    }

    // MARK: - Alias calculations
    func testIncrementAlias48() {
        // check precision of calculation
        XCTAssertEqual(CanLink.incrementAlias48(0), 0x1B0C_A37A_4BA9, "0 initial value")

        // test shift and multiplation operations
        let next : UInt64 = CanLink.incrementAlias48(0x0000_0000_0001)
        XCTAssertEqual(next, 0x1B0C_A37A_4FAA)
    }

    func testCreateAlias12() {
        // check precision of calculation
        XCTAssertEqual(CanLink.createAlias12(0x001), 0x001, "0x001 input")
        XCTAssertEqual(CanLink.createAlias12(0x1_000), 0x001, "0x1000 input")
        XCTAssertEqual(CanLink.createAlias12(0x1_000_000), 0x001, "0x1000000 input")

        XCTAssertEqual(CanLink.createAlias12(0x4_002_001), 0x007)
        
        XCTAssertEqual(CanLink.createAlias12(0x1001), 0x002, "0x1001 random input checks against zero")
        
        XCTAssertEqual(CanLink.createAlias12(0x0000), 0xAEF, "zero input check")

    }
    
    // MARK: - Test PHY Up
    func testLinkUpSequence() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)

        canPhysicalLayer.physicalLayerUp()

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 7)  // TODO: includes AMD, AME w/o delay now
        XCTAssertEqual(canLink.state, CanLink.State.Permitted)

        XCTAssertEqual(messageLayer.receivedMessages.count, 1)
    }

    // MARK: - Test PHY Down, Up, Error Information
    func testLinkDownSequence() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        canLink.state = CanLink.State.Permitted
        
        canPhysicalLayer.physicalLayerDown()

        XCTAssertEqual(canLink.state, CanLink.State.Inhibited)
        XCTAssertEqual(messageLayer.receivedMessages.count, 1)
    }

    func testAEIE2noData() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted

        canPhysicalLayer.fireListeners(CanFrame(control: CanLink.ControlFrame.EIR2.rawValue, alias: 0))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)
    }

    // MARK: - Test AME (Local Node)
    func testAMEnoData() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.state = CanLink.State.Permitted

        canPhysicalLayer.fireListeners(CanFrame(control: CanLink.ControlFrame.AME.rawValue, alias: 0))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0], CanFrame(control: CanLink.ControlFrame.AMD.rawValue, alias: ourAlias))
    }
 
    func testAMEnoDataInhibited() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Inhibited

        canPhysicalLayer.fireListeners(CanFrame(control: CanLink.ControlFrame.AME.rawValue, alias: 0))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)
    }
 
    func testAMEMatchEvent() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted

        var frame = CanFrame(control: CanLink.ControlFrame.AME.rawValue, alias: 0)
        frame.data = [5,1,1,1,3,1]
        canPhysicalLayer.fireListeners(frame)
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0], CanFrame(control: CanLink.ControlFrame.AMD.rawValue, alias: ourAlias))
    }

    func testAMEnotMatchEvent() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted

        var frame = CanFrame(control: CanLink.ControlFrame.AME.rawValue, alias: 0)
        frame.data = [0,0,0,0,0,0]
        canPhysicalLayer.fireListeners(frame)
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)
    }

    // MARK: - Test Alias Collisions (Local Node)
    func testCIDreceivedMatch() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted

        canPhysicalLayer.fireListeners(CanFrame(cid: 7, nodeID: CanLink.localNodeID, alias: ourAlias))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0], CanFrame(control: CanLink.ControlFrame.RID.rawValue, alias: ourAlias))
    }
    
    func testRIDreceivedMatch() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted

        canPhysicalLayer.fireListeners(CanFrame(control: CanLink.ControlFrame.RID.rawValue, alias: ourAlias))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0], CanFrame(control: CanLink.ControlFrame.AMR.rawValue, alias: ourAlias))
        XCTAssertEqual(canLink.state, CanLink.State.Inhibited)
    }
    
    // TODO: test message transfer
    
    func testCheckMTImapping() {
        
        let canLink = CanLink()
        XCTAssertEqual(canLink.canHeaderToFullFormat(frame: CanFrame(header:0x19490247, data:[]) ),
                       MTI.VerifyNodeIDNumberGlobal )
    }

    func testSimpleGlobalData() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        canLink.state = .Permitted

        // map an alias we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [01,02,03,04,05,06]
        canPhysicalLayer.fireListeners(amd)

        canPhysicalLayer.fireListeners(CanFrame(control: 0x19490, alias: 0x247)) // from previously seen alias

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0) // nothing back down to CAN
        XCTAssertEqual(messageLayer.receivedMessages.count, 1) // one message forwarded
        // check for proper global MTI
        XCTAssertEqual(messageLayer.receivedMessages[0].mti,
                       MTI.VerifyNodeIDNumberGlobal)
        XCTAssertEqual(messageLayer.receivedMessages[0].source,
                       NodeID(0x010203040506))
    }

    func testSimpleAddressedData() { // Test start=yes, end=yes frame
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)

        canPhysicalLayer.physicalLayerUp()

        // map an alias we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [01,02,03,04,05,06]
        canPhysicalLayer.fireListeners(amd)

        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        var frame = CanFrame(control: 0x19488, alias: 0x247) // Verify Node ID Addressed
        frame.data = [UInt8((ourAlias & 0x700)>>8), UInt8(ourAlias&0xFF), 12, 13]
        canPhysicalLayer.fireListeners(frame) // from previously seen alias

        XCTAssertEqual(messageLayer.receivedMessages.count, 2) // startup plus one message forwarded
        // check for proper global MTI
        XCTAssertEqual(messageLayer.receivedMessages[1].mti,
                       MTI.VerifyNodeIDNumberAddressed)
        XCTAssertEqual(messageLayer.receivedMessages[1].source,
                       NodeID(0x01_02_03_04_05_06))
        XCTAssertEqual(messageLayer.receivedMessages[1].destination,
                       NodeID(0x05_01_01_01_03_01))
        XCTAssertEqual(messageLayer.receivedMessages[1].data.count, 2)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[0], 12)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[1], 13)
    }
    
    // multi-frame addressed messages - SNIP reply
    func testMultiFrameAddressedData() { // Test message in 3 frames
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)

        canPhysicalLayer.physicalLayerUp()

        // map an alias we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [01,02,03,04,05,06]
        canPhysicalLayer.fireListeners(amd)

        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        var frame = CanFrame(control: 0x19488, alias: 0x247) // Verify Node ID Addressed
        frame.data = [(UInt8((ourAlias & 0x700)>>8) | 0x10), UInt8(ourAlias&0xFF), 1, 2]  // start not end
        canPhysicalLayer.fireListeners(frame) // from previously seen alias

        XCTAssertEqual(messageLayer.receivedMessages.count, 1) // startup only, no message forwarded yet
        
        frame = CanFrame(control: 0x19488, alias: 0x247) // Verify Node ID Addressed
        frame.data = [(UInt8((ourAlias & 0x700)>>8) | 0x20), UInt8(ourAlias&0xFF), 3, 4]  // end, not start
        canPhysicalLayer.fireListeners(frame) // from previously seen alias

        XCTAssertEqual(messageLayer.receivedMessages.count, 2) // startup plus one message forwarded

        // check for proper global MTI
        XCTAssertEqual(messageLayer.receivedMessages[1].mti,
                       MTI.VerifyNodeIDNumberAddressed)
        XCTAssertEqual(messageLayer.receivedMessages[1].source,
                       NodeID(0x01_02_03_04_05_06))
        XCTAssertEqual(messageLayer.receivedMessages[1].destination,
                       NodeID(0x05_01_01_01_03_01))
    }

    // TODO:    datagrams short and long
    
    // MARK: - Test Remote Node Alias Tracking
    // TODO: - Test Remote Node Alias Tracking
    
    // TODO:    single frame messages - addressed and not
    func testAmdAmrSequence() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.linkPhysicalLayer(canPhysicalLayer)

        canPhysicalLayer.fireListeners(CanFrame(control: 0x0701, alias: ourAlias+1)) // AMD from some other alias

        XCTAssertEqual(canLink.aliasToNodeID.count, 1)
        XCTAssertEqual(canLink.nodeIdToAlias.count, 1)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0) // nothing back down to CAN

        canPhysicalLayer.fireListeners(CanFrame(control: 0x0703, alias: ourAlias+1)) // AMR from some other alias

        XCTAssertEqual(canLink.aliasToNodeID.count, 0)
        XCTAssertEqual(canLink.nodeIdToAlias.count, 0)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0) // nothing back down to CAN
    }

    
}
