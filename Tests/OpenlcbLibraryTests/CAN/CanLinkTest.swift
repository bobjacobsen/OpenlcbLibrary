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
    
    /// Mock Message to record messages requested to be sent
    class MessageMockLayer {
        var receivedMessages : [Message] = []
        func receiveMessage(_ msg : Message) { receivedMessages.append(msg) }
    }
  
    class PhyMockLayer : CanPhysicalLayer {
        var receivedFrames : [CanFrame] = []
        override func sendCanFrame(_ frame : CanFrame) { receivedFrames.append(frame) }
    }

    // MARK: - Alias calculations
    func testIncrementAlias48() {
        // check precision of calculation
        XCTAssertEqual(CanLink.incrementAlias48(0), 0x1B0C_A37A_4BA9, "0 initial value")
        
        // test shift and multiplation operations
        let next : UInt64 = CanLink.incrementAlias48(0x0000_0000_0001)
        XCTAssertEqual(next, 0x1B0C_A37A_4DAA)
    }
    
    func testIncrementAliasSequence() {
        // sequence from TN
        var next = CanLink.incrementAlias48(0);
        XCTAssertEqual(next, 0x1B0C_A37A_4BA9, "0 initial value")
        
        next = CanLink.incrementAlias48(next);
        XCTAssertEqual(next, 0x4F_60_3B_8B_E9_52)
        
        next = CanLink.incrementAlias48(next);
        XCTAssertEqual(next, 0x2A_E3_F6_D8_D8_FB)
        
        next = CanLink.incrementAlias48(next);
        XCTAssertEqual(next, 0x0D_DE_4C_05_1A_A4)
        
        next = CanLink.incrementAlias48(next);
        XCTAssertEqual(next, 0xE5_82_F9_B4_AE_4D)
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
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        
        canPhysicalLayer.physicalLayerUp()
        
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 7)
        XCTAssertEqual(canLink.state, CanLink.State.Permitted)
        
        XCTAssertEqual(messageLayer.receivedMessages.count, 1)
    }
    
    // MARK: - Test PHY Down, Up, Error Information
    func testLinkDownSequence() {
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        canLink.state = CanLink.State.Permitted
        
        canPhysicalLayer.physicalLayerDown()
        
        XCTAssertEqual(canLink.state, CanLink.State.Inhibited)
        XCTAssertEqual(messageLayer.receivedMessages.count, 1)
    }
    
    func testAEIE2noData() {
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted
        
        canPhysicalLayer.fireListeners(CanFrame(control: CanLink.ControlFrame.EIR2.rawValue, alias: 0))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)
    }
    
    // MARK: - Test AME (Local Node)
    func testAMEnoData() {
        // Receive an AME in Permitted state without a NodeID
        // Test that an AMD frame with proper contents is sent.
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.state = CanLink.State.Permitted
        
        canPhysicalLayer.fireListeners(CanFrame(control: CanLink.ControlFrame.AME.rawValue, alias: 0))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0], CanFrame(control: CanLink.ControlFrame.AMD.rawValue, alias: ourAlias, data: canLink.localNodeID.toArray()))
    }
    
    func testAMEnoDataInhibited() {
        // Receive an AME in Inhibited state without a NodeID
        // Test that no response is sent.
       let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Inhibited
        
        canPhysicalLayer.fireListeners(CanFrame(control: CanLink.ControlFrame.AME.rawValue, alias: 0))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)
    }
    
    func testAMEMatchNode() {
        // Receive an AME with our NodeID in Permitted state
        // Test that an AMD frame with proper contents is sent.
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted
        
        var frame = CanFrame(control: CanLink.ControlFrame.AME.rawValue, alias: 0)
        frame.data = [5,1,1,1,3,1]
        canPhysicalLayer.fireListeners(frame)
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0], CanFrame(control: CanLink.ControlFrame.AMD.rawValue, alias: ourAlias, data: canLink.localNodeID.toArray()))
    }
    
    func testAMEnotMatchNode() {
        // Receive an AME in Permitted state with an NodeID,  but not a NodeID we know about.
        // Test that no response is sent.
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted
        
        var frame = CanFrame(control: CanLink.ControlFrame.AME.rawValue, alias: 0)
        frame.data = [0,0,0,0,0,0]
        canPhysicalLayer.fireListeners(frame)
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)
    }
    
    // MARK: - Test Alias Collisions (Local Node)
    func testCIDreceivedMatch() {
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted
        
        canPhysicalLayer.fireListeners(CanFrame(cid: 7, nodeID: canLink.localNodeID, alias: ourAlias))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0], CanFrame(control: CanLink.ControlFrame.RID.rawValue, alias: ourAlias))
    }
    
    func testRIDreceivedMatch() {
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted
        
        canPhysicalLayer.fireListeners(CanFrame(control: CanLink.ControlFrame.RID.rawValue, alias: ourAlias))
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 8)  // includes recovery of new alias 4 CID, RID, AMR, AME
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0], CanFrame(control: CanLink.ControlFrame.AMR.rawValue, alias: ourAlias, data: [5, 1, 1, 1, 3, 1]))
        XCTAssertEqual(canPhysicalLayer.receivedFrames[6], CanFrame(control: CanLink.ControlFrame.AMD.rawValue, alias: 0x539, data: [5, 1, 1, 1, 3, 1])) // new alias
        XCTAssertEqual(canLink.state, CanLink.State.Permitted)
    }
    
    func testCheckMTImapping() {
        
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        XCTAssertEqual(canLink.canHeaderToFullFormat(frame: CanFrame(header:0x19490247, data:[]) ),
                       MTI.Verify_NodeID_Number_Global )
    }
    
    func testControlFrameDecode() {
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        let frame = CanFrame(control: 0x1000, alias: 0x000)  // invalid control frame content
        XCTAssertEqual(canLink.decodeControlFrameFormat(frame), CanLink.ControlFrame.UnknownFormat)
        
    }
    
    func testSimpleGlobalData() {
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
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
                       MTI.Verify_NodeID_Number_Global)
        XCTAssertEqual(messageLayer.receivedMessages[0].source,
                       NodeID(0x010203040506))
    }
    
    func testVerifiedNodeInDestAliasMap() {
        // JMRI doesn't send AMD, so gets assigned 00.00.00.00.00.00
        // This tests that a VerifiedNode will update that.
        
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        canLink.state = .Permitted
        
        // Don't map an alias with an AMD for this test
        
        canPhysicalLayer.fireListeners(CanFrame(control: 0x19170, alias: 0x247, data: [08,07,06,05,04,03])) // VerifiedNodeID from unique alias
        
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0) // nothing back down to CAN
        XCTAssertEqual(messageLayer.receivedMessages.count, 1) // one message forwarded
        // check for proper global MTI
        XCTAssertEqual(messageLayer.receivedMessages[0].mti,
                       MTI.Verified_NodeID)
        XCTAssertEqual(messageLayer.receivedMessages[0].source,
                       NodeID(0x080706050403))
    }
    
    func testNoDestInAliasMap() {
        // Tests receipt of a frame with a destination alias not in map (can happen after AME-no-NodeID clears caches)
        
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        canLink.state = .Permitted
        
        // Don't map an alias with an AMD for this test
        
        canPhysicalLayer.fireListeners(CanFrame(control: 0x19968, alias: 0x247, data: [08,07,06,05,04,03])) // Identify Events Addressed from unique alias
        
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0) // nothing back down to CAN
        XCTAssertEqual(messageLayer.receivedMessages.count, 1) // one message forwarded
        // check for proper global MTI
        XCTAssertEqual(messageLayer.receivedMessages[0].mti,
                       MTI.Identify_Events_Addressed)
        XCTAssertEqual(messageLayer.receivedMessages[0].source,
                       NodeID(0x000000000001))
    }
    
    // MARK: Test received data frames
    
    func testSimpleAddressedData() { // Test start=yes, end=yes frame
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
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
                       MTI.Verify_NodeID_Number_Addressed)
        XCTAssertEqual(messageLayer.receivedMessages[1].source,
                       NodeID(0x01_02_03_04_05_06))
        XCTAssertEqual(messageLayer.receivedMessages[1].destination,
                       NodeID(0x05_01_01_01_03_01))
        XCTAssertEqual(messageLayer.receivedMessages[1].data.count, 2)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[0], 12)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[1], 13)
    }
    
    func testSimpleAddressedDataNoAliasYet() { // Test start=yes, end=yes frame with no alias match
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        
        canPhysicalLayer.physicalLayerUp()
        
        // don't map alias with AMD
        
        // receive Verify Node ID Addressed from unknown alias
        let ourAlias = canLink.localAlias // 576 with NodeID(0x05_01_01_01_03_01)
        var frame = CanFrame(control: 0x19488, alias: 0x247) // Verify Node ID Addressed
        frame.data = [UInt8((ourAlias & 0x700)>>8), UInt8(ourAlias&0xFF), 12, 13]
        canPhysicalLayer.fireListeners(frame) // from previously seen alias
        
        XCTAssertEqual(messageLayer.receivedMessages.count, 2) // startup plus one message forwarded
        // check for proper global MTI
        XCTAssertEqual(messageLayer.receivedMessages[1].mti,
                       MTI.Verify_NodeID_Number_Addressed)
        XCTAssertEqual(messageLayer.receivedMessages[1].source,
                       NodeID(0x00_00_00_00_00_01))
        XCTAssertEqual(messageLayer.receivedMessages[1].destination,
                       NodeID(0x05_01_01_01_03_01))
        XCTAssertEqual(messageLayer.receivedMessages[1].data.count, 2)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[0], 12)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[1], 13)
    }
    
    // multi-frame addressed messages - SNIP reply
    func testMultiFrameAddressedData() { // Test message in 3 frames
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
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
                       MTI.Verify_NodeID_Number_Addressed)
        XCTAssertEqual(messageLayer.receivedMessages[1].source,
                       NodeID(0x01_02_03_04_05_06))
        XCTAssertEqual(messageLayer.receivedMessages[1].destination,
                       NodeID(0x05_01_01_01_03_01))
    }
    
    func testSimpleDatagrm() { // Test start=yes, end=yes frame
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        
        canPhysicalLayer.physicalLayerUp()
        
        // map two aliases we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [01,02,03,04,05,06]
        canPhysicalLayer.fireListeners(amd)
        amd = CanFrame(control: 0x0701, alias: 0x123)
        amd.data = [6,5,4,3,2,1]
        canPhysicalLayer.fireListeners(amd)

        var frame = CanFrame(control: 0x1A123, alias: 0x247) // single frame datagram
        frame.data = [10, 11, 12, 13]
        canPhysicalLayer.fireListeners(frame) // from previously seen alias
        
        XCTAssertEqual(messageLayer.receivedMessages.count, 2) // startup plus one message forwarded
        // check for proper global MTI
        XCTAssertEqual(messageLayer.receivedMessages[1].mti,
                       MTI.Datagram)
        XCTAssertEqual(messageLayer.receivedMessages[1].source,
                       NodeID(0x01_02_03_04_05_06))
        XCTAssertEqual(messageLayer.receivedMessages[1].destination,
                       NodeID(0x06_05_04_03_02_01))
        XCTAssertEqual(messageLayer.receivedMessages[1].data.count, 4)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[0], 10)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[1], 11)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[2], 12)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[3], 13)
    }

    func testThreeFrameDatagrm() {
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        let messageLayer = MessageMockLayer()
        canLink.registerMessageReceivedListener(messageLayer.receiveMessage)
        
        canPhysicalLayer.physicalLayerUp()
        
        // map two aliases we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [01,02,03,04,05,06]
        canPhysicalLayer.fireListeners(amd)
        amd = CanFrame(control: 0x0701, alias: 0x123)
        amd.data = [6,5,4,3,2,1]
        canPhysicalLayer.fireListeners(amd)

        var frame = CanFrame(control: 0x1B123, alias: 0x247) // single frame datagram
        frame.data = [10, 11, 12, 13]
        canPhysicalLayer.fireListeners(frame) // from previously seen alias
        frame = CanFrame(control: 0x1C123, alias: 0x247) // single frame datagram
        frame.data = [20, 21, 22, 23]
        canPhysicalLayer.fireListeners(frame) // from previously seen alias
        frame = CanFrame(control: 0x1D123, alias: 0x247) // single frame datagram
        frame.data = [30, 31, 32, 33]
        canPhysicalLayer.fireListeners(frame) // from previously seen alias

        XCTAssertEqual(messageLayer.receivedMessages.count, 2) // startup plus one message forwarded
        // check for proper global MTI
        XCTAssertEqual(messageLayer.receivedMessages[1].mti,
                       MTI.Datagram)
        XCTAssertEqual(messageLayer.receivedMessages[1].source,
                       NodeID(0x01_02_03_04_05_06))
        XCTAssertEqual(messageLayer.receivedMessages[1].destination,
                       NodeID(0x06_05_04_03_02_01))
        XCTAssertEqual(messageLayer.receivedMessages[1].data.count, 12)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[0], 10)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[1], 11)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[2], 12)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[3], 13)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[4], 20)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[5], 21)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[6], 22)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[7], 23)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[8], 30)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[9], 31)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[10], 32)
        XCTAssertEqual(messageLayer.receivedMessages[1].data[11], 33)
    }
    
    func testZeroLengthDatagram (){
        let canPhysicalLayer = PhyMockLayer()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)

        // map alias we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [05,01,01,01,03,01]
        canPhysicalLayer.fireListeners(amd)

        let message = Message(mti: .Datagram, source: NodeID("05.01.01.01.03.01"), destination: NodeID("05.01.01.01.03.01"))
        
        canLink.sendMessage(message)
        
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].description, "CanFrame header: 0x1A247247 ) []")

    }

    // MARK: Test transmitting messages
    
    func testOneFrameDatagram (){
        let canPhysicalLayer = PhyMockLayer()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        
        // map alias we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [05,01,01,01,03,01]
        canPhysicalLayer.fireListeners(amd)
        
        let message = Message(mti: .Datagram, source: NodeID("05.01.01.01.03.01"), destination: NodeID("05.01.01.01.03.01"), data: [1,2,3,4,5,6,7,8])
        
        canLink.sendMessage(message)
        
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].description, "CanFrame header: 0x1A247247 ) [1, 2, 3, 4, 5, 6, 7, 8]")
    }
    
    func testOneFrameDatagramUnknownDest (){
        let canPhysicalLayer = PhyMockLayer()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        
        // map alias we'll use for source
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [05,01,01,01,03,01]
        canPhysicalLayer.fireListeners(amd)
        
        let message = Message(mti: .Datagram, source: NodeID("05.01.01.01.03.01"), destination: NodeID("05.01.01.01.03.02"), data: [1,2,3,4,5,6,7,8])
        
        canLink.sendMessage(message)
        
        // This will have queued the message. Should have sent an AME for the alias
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].description, "CanFrame header: 0x10702240 ) [5, 1, 1, 1, 3, 2]")

        // Now map the destination alias and expect the message to be sent
        amd = CanFrame(control: 0x0701, alias: 0x248)
        amd.data = [05,01,01,01,03,02]
        canPhysicalLayer.fireListeners(amd)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 2)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[1].description, "CanFrame header: 0x1A248247 ) [1, 2, 3, 4, 5, 6, 7, 8]")
        
    }
    

    func testTwoFrameDatagram (){
        let canPhysicalLayer = PhyMockLayer()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)
        
        // map alias we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [05,01,01,01,03,01]
        canPhysicalLayer.fireListeners(amd)

        let message = Message(mti: .Datagram, source: NodeID("05.01.01.01.03.01"), destination: NodeID("05.01.01.01.03.01"), data: [1,2,3,4,5,6,7,8, 9,10,11,12,13,14,15,16])
        
        canLink.sendMessage(message)
        
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 2)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].description, "CanFrame header: 0x1B247247 ) [1, 2, 3, 4, 5, 6, 7, 8]")
        XCTAssertEqual(canPhysicalLayer.receivedFrames[1].description, "CanFrame header: 0x1D247247 ) [9, 10, 11, 12, 13, 14, 15, 16]")
    }
    
    func testThreeFrameDatagram (){
        let canPhysicalLayer = PhyMockLayer()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        canLink.linkPhysicalLayer(canPhysicalLayer)

        // map alias we'll use
        var amd = CanFrame(control: 0x0701, alias: 0x247)
        amd.data = [05,01,01,01,03,01]
        canPhysicalLayer.fireListeners(amd)

        let message = Message(mti: .Datagram, source: NodeID("05.01.01.01.03.01"), destination: NodeID("05.01.01.01.03.01"), data: [1,2,3,4,5,6,7,8, 9,10,11,12,13,14,15,16, 17,18,19])
        
        canLink.sendMessage(message)
        
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 3)
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].description, "CanFrame header: 0x1B247247 ) [1, 2, 3, 4, 5, 6, 7, 8]")
        XCTAssertEqual(canPhysicalLayer.receivedFrames[1].description, "CanFrame header: 0x1C247247 ) [9, 10, 11, 12, 13, 14, 15, 16]")
        XCTAssertEqual(canPhysicalLayer.receivedFrames[2].description, "CanFrame header: 0x1D247247 ) [17, 18, 19]")
    }
    
    // MARK: - Test Remote Node Alias Tracking
    
    func testAmdAmrSequence() {
        let canPhysicalLayer = CanPhysicalLayerSimulation()
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
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
    
    // MARK: - Data size handling
    
    func testSegmentAddressedDataArray() {
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        
        // no data
        XCTAssertEqual(canLink.segmentAddressedDataArray(UInt(0x123), []), [[0x1,0x23]])
        
        // short data
        XCTAssertEqual(canLink.segmentAddressedDataArray(UInt(0x123), [0x1, 0x2]), [[0x1,0x23, 0x01, 0x02]])
        
        // full first frame
        XCTAssertEqual(canLink.segmentAddressedDataArray(UInt(0x123), [0x1, 0x2, 0x3, 0x4, 0x5, 0x6]), [[0x1,0x23, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6]])
        
        // two frames needed
        XCTAssertEqual(canLink.segmentAddressedDataArray(UInt(0x123), [0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7]), [[0x11,0x23, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6], [0x21,0x23, 0x7]])
        
        // two full frames needed
        XCTAssertEqual(canLink.segmentAddressedDataArray(UInt(0x123), [0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC]),
                       [[0x11,0x23, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6], [0x21,0x23, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC]])
        
        // three frames needed
        XCTAssertEqual(canLink.segmentAddressedDataArray(UInt(0x123), [0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE]),
                       [[0x11,0x23, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6], [0x31,0x23, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC], [0x21, 0x23, 0xD, 0xE]])
    }
    
    func testSegmentDatagramDataArray() {
        let canLink = CanLink(localNodeID: NodeID("05.01.01.01.03.01"))
        
        // no data
        XCTAssertEqual(canLink.segmentDatagramDataArray([]), [[]])
        
        // short data
        XCTAssertEqual(canLink.segmentDatagramDataArray([0x1, 0x2]), [[0x01, 0x02]])
        
        // partially full first frame
        XCTAssertEqual(canLink.segmentDatagramDataArray([0x1, 0x2, 0x3, 0x4, 0x5, 0x6]), [[0x1, 0x2, 0x3, 0x4, 0x5, 0x6]])
        
        // one full frame needed
        XCTAssertEqual(canLink.segmentDatagramDataArray([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8]), [[0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8]])
        
        // two frames needed
        XCTAssertEqual(canLink.segmentDatagramDataArray([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9]), [[0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8], [0x9]])
        
        // two full frames needed
        XCTAssertEqual(canLink.segmentDatagramDataArray([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x10]),
                       [[0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8], [0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x10]])
        
        // three frames needed
        XCTAssertEqual(canLink.segmentDatagramDataArray([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x10, 0x11]),
                       [[0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8], [0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x10], [0x11]])
    }
}
