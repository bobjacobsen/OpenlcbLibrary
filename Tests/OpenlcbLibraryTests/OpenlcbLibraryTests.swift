import XCTest
@testable import OpenlcbLibrary

final class OpenlcbLibraryTests: XCTestCase {
    
    let canPhysicalLayer = CanPhysicalLayerMock()
    
    func testCanSetup() {
        let lib = OpenlcbLibrary()
        lib.configureCanTelnet(canPhysicalLayer)
        
        lib.createSampleData()
        
        lib.bringLinkUp(canPhysicalLayer)
        
        XCTAssertEqual(OpenlcbLibrary.defaultNode.state, Node.State.Initialized)
        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 8) // should be 8 with the Initialization complete
        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[5].header))", "0x00701240") // Allocation AMDefinition
        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[6].header))", "0x00702240") // Acquire rest of network with AMEnquiry

        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[7].header))", "0x19100240") // Initialization complete
        XCTAssertEqual(canPhysicalLayer.receivedFrames[7].data, [5,1,1,1,3,1]) // carries nodeID

        canPhysicalLayer.receivedFrames = []
        
        // AMR reply from our test node
        var header : UInt = 0x00701_111
        var data : [UInt8] = [01,01,01,01,01,01]
        var frame = CanFrame(header: header, data : data)
        canPhysicalLayer.fireListeners(frame)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 0)  // we don't reply to AMR

        canPhysicalLayer.receivedFrames = []

        // run a verify node global operation
        header = 0x19_490_111
        data = []
        frame = CanFrame(header: header, data : data)
        canPhysicalLayer.fireListeners(frame)

        XCTAssertEqual(canPhysicalLayer.receivedFrames.count, 1)
        XCTAssertEqual("\(String(format:"0x%08X", canPhysicalLayer.receivedFrames[0].header))", "0x19170240") // Verified Node 
        XCTAssertEqual(canPhysicalLayer.receivedFrames[0].data, [5,1,1,1,3,1]) // carries nodeID

    }
    
}
