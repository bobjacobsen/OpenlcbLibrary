//
//  OpenlcbLibraryTests.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//
/// Tests creation and operation of the basic setup.


import XCTest
@testable import OpenlcbLibrary

final class OpenlcbLibraryTests: XCTestCase {
    
    let canPhysicalLayer = CanPhysicalLayerSimulation()
    
    func testCanSetupRuns() {
        let lib = OpenlcbLibrary(defaultNodeID: NodeID(0x05_01_01_01_03_01))
        lib.configureCanTelnet(canPhysicalLayer)
        
        lib.createSampleData()
        XCTAssertEqual(lib.remoteNodeStore.asArray().count, 7)
        
        lib.bringLinkUp(canPhysicalLayer)
    }
    
    /// More of an acceptance test than a unit test.
    func testOperation() {
        let lib = OpenlcbLibrary(defaultNodeID: NodeID(0x05_01_01_01_03_01))
        lib.configureCanTelnet(canPhysicalLayer)
        lib.createSampleData()
        lib.bringLinkUp(canPhysicalLayer)
        
        // check initialization messages
        XCTAssertEqual(lib.defaultNode.state, Node.State.Initialized)
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 9) // should be 8 with the Initialization Complete and Verify Global
        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[5].header))", "0x10701240") // Allocation AMDefinition
        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[6].header))", "0x10702240") // Acquire rest of network with AMEnquiry

        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[7].header))", "0x19100240") // Initialization complete
        XCTAssertEqual(canPhysicalLayer.receivedFrames[7].data, [5,1,1,1,3,1]) // carries nodeID

        canPhysicalLayer.receivedFrames = []
        
        XCTAssertFalse(lib.remoteNodeStore.isPresent(NodeID([03,03,03,03,03,03]))) // remote node not created yet

        
        // Provide AMR reply from our test node
        var header : UInt = 0x00701_333
        var data : [UInt8] = [03,03,03,03,03,03]
        var frame = CanFrame(header: header, data: data)
        canPhysicalLayer.fireListeners(frame)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)  // we don't reply to AMR
        XCTAssertFalse(lib.remoteNodeStore.isPresent(NodeID([03,03,03,03,03,03]))) // remote node not created by AMR, needs a message-level reception

        canPhysicalLayer.receivedFrames = []

        
        // Run a verify node global operation on our node 
        header = 0x19_490_333
        data = [] // address
        frame = CanFrame(header: header, data: data)
        canPhysicalLayer.fireListeners(frame)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[0].header))", "0x19170240") // Verified Node
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].data, [5,1,1,1,3,1]) // carries nodeID

        canPhysicalLayer.receivedFrames = []

        
        // A remote node globally identified, so should be remote node in store with right state
        header = 0x19_170_333    // verified NodeID
        data = [03,03,03,03,03,03]
        frame = CanFrame(header: header, data : data)
        canPhysicalLayer.fireListeners(frame)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)
        XCTAssertTrue(lib.remoteNodeStore.isPresent(NodeID([03,03,03,03,03,03])))
        XCTAssertEqual(lib.remoteNodeStore.lookup(NodeID([03,03,03,03,03,03]))!.state, Node.State.Initialized)

        canPhysicalLayer.receivedFrames = []

        // predefined nodes also present, but not yet Initialized
        XCTAssertTrue(lib.remoteNodeStore.isPresent(NodeID([02,02,02,02,02,02])))
        XCTAssertEqual(lib.remoteNodeStore.lookup(NodeID([02,02,02,02,02,02]))!.state, Node.State.Uninitialized)
    
        
        // PIP request not to us
        
        header = 0x19_828_333
        data = [0x03, 0x33]
        frame = CanFrame(header: header, data : data)
        canPhysicalLayer.fireListeners(frame)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)

        
        // PIP request to us
        header = 0x19_828_333
        data = [0x02, 0x40]
        frame = CanFrame(header: header, data : data)
        canPhysicalLayer.fireListeners(frame)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[0].header))", "0x19668240") // PIP Reply
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].data, [0x03, 0x33, 0x44, 0x10, 0x00, 0x00, 0x00, 0x00]) // carries nodeID & PIP Data

        canPhysicalLayer.receivedFrames = []

        
        // SNIP request to us
        header = 0x19_DE8_333
        data = [0x02, 0x40]
        frame = CanFrame(header: header, data : data)
        canPhysicalLayer.fireListeners(frame)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 14)
        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[0].header))", "0x19A08240") // SNIP Reply
        
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].data, [0x13, 0x33, 0x04, 0x41, 0x72, 0x64, 0x65, 0x6E]) // carries nodeID & SNIP Data
        XCTAssertEqual(canPhysicalLayer.receivedFrames[1].data, [0x33, 0x33, 0x77, 0x6F, 0x6F, 0x64, 0x2E, 0x6E]) // carries nodeID & SNIP Data
        XCTAssertEqual(canPhysicalLayer.receivedFrames[5].data, [0x33, 0x33, 0x2E, 0x30, 0x2E, 0x31, 0x00, 0x02]) // carries nodeID & SNIP Data
        XCTAssertEqual(canPhysicalLayer.receivedFrames[13].data,[0x23, 0x33, 0x65, 0x74, 0x29, 0x00]) // carries nodeID & SNIP Data

        canPhysicalLayer.receivedFrames = []

   }

}
