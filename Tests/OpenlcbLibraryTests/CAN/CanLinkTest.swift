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

        canPhysicalLayer.physicalLayerUp()

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 5)
        XCTAssertEqual(canLink.state, CanLink.State.Inhibited)
    }

    // MARK: - Test PHY Down, Up, Error Information
    func testLinkDownSequence() {
        let canPhysicalLayer = CanMockPhysicalLayer()
        let canLink = CanLink()
        canLink.linkPhysicalLayer(canPhysicalLayer)
        canLink.state = CanLink.State.Permitted
        
        canPhysicalLayer.physicalLayerDown()

        XCTAssertEqual(canLink.state, CanLink.State.Inhibited)
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
    
    // MARK: - Test Remote Node Alias Tracking
    
    
    
}
