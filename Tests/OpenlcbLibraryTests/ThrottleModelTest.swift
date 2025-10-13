//
//  ThrottleModelTest.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import XCTest
@testable import OpenlcbLibrary

final class ThrottleModelTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testcreateQueryEventID() throws {
        var eventID = ThrottleModel.createQueryEventID(matching: 2)
        XCTAssertEqual(EventID([0x09, 0x00, 0x99, 0xFF, 0x2F, 0xFF, 0xFF, 0xE0]), eventID)

        eventID = ThrottleModel.createQueryEventID(matching: 12)
        XCTAssertEqual(EventID([0x09, 0x00, 0x99, 0xFF, 0x12, 0xFF, 0xFF, 0xE0]), eventID)

        eventID = ThrottleModel.createQueryEventID(matching: 123)
        XCTAssertEqual(EventID([0x09, 0x00, 0x99, 0xFF, 0x12, 0x3F, 0xFF, 0xE0]), eventID)

        eventID = ThrottleModel.createQueryEventID(matching: 1234)
        XCTAssertEqual(EventID([0x09, 0x00, 0x99, 0xFF, 0x12, 0x34, 0xFF, 0xE0]), eventID)
    }

    func testEncodeSpeed() {
        let model = ThrottleModel( CanLink(localNodeID: NodeID(11)))
        
        XCTAssertEqual(model.encodeSpeed(to: 100.0, reverse: false), [0x97, 0x51])
        
        XCTAssertEqual(model.encodeSpeed(to:  50.0, reverse: false), [0x97, 0x4D])

        XCTAssertEqual(model.encodeSpeed(to:  25.0, reverse: false), [0x97, 0x49])

        XCTAssertEqual(model.encodeSpeed(to:  10.0, reverse: false), [0x78, 0x44])

        XCTAssertEqual(model.encodeSpeed(to:   2.0, reverse: false), [0x27, 0x3B])

        XCTAssertEqual(model.encodeSpeed(to:  50.0, reverse: true), [0x97, 0xCD])

        XCTAssertEqual(model.encodeSpeed(to:   2.0, reverse: true), [0x27, 0xBB])
    }
 
    func testPadWithZero() {
        XCTAssertEqual(RosterEntry.padFrontWithZero("ABC"), "00000000ABC")
        XCTAssertEqual(RosterEntry.padFrontWithZero("2L"),  "00000002L")
        XCTAssertEqual(RosterEntry.padFrontWithZero("2"),   "00000002")
        XCTAssertEqual(RosterEntry.padFrontWithZero("100"), "00000100")
        XCTAssertEqual(RosterEntry.padFrontWithZero("100L"),"00000100L")
    }
    
    func testSortBy() {
        let reNone = RosterEntry(label: "<None>", nodeID: NodeID(0), labelSource: .Initial)
        let reBar   = RosterEntry(label: "Bar", nodeID: NodeID(0), labelSource: .Initial)
        let reBiff  = RosterEntry(label: "Biff", nodeID: NodeID(0), labelSource: .Initial)
        let reFoo   = RosterEntry(label: "Foo", nodeID: NodeID(0), labelSource: .Initial)
        let re2     = RosterEntry(label: "2", nodeID: NodeID(0), labelSource: .Initial)
        let re03    = RosterEntry(label: "3", nodeID: NodeID(0), labelSource: .Initial)
        let re100   = RosterEntry(label: "100", nodeID: NodeID(0), labelSource: .Initial)

        XCTAssertTrue(RosterEntry.sortBy(reNone, re2) )
        XCTAssertTrue(RosterEntry.sortBy(reBar,  reFoo) )
        XCTAssertTrue(RosterEntry.sortBy(reBiff, reFoo) )
        XCTAssertTrue(RosterEntry.sortBy(reFoo,  re2) )
        XCTAssertTrue(RosterEntry.sortBy(re2,    re03) )
        XCTAssertTrue(RosterEntry.sortBy(re2,    re100) )
        XCTAssertTrue(RosterEntry.sortBy(re03,   re100) )

        XCTAssertFalse(RosterEntry.sortBy(re2, re2) )
        XCTAssertFalse(RosterEntry.sortBy(reNone, reNone) )
    }
    
#if arch(arm64)
    // on Arm64 (Apple Silicon), we can test our Float16 <-> Float routines against the native ones

    func testFToF16 () {
        XCTAssertEqual(floatToFloat16(100.0), Float16(100.0).bytes)
        XCTAssertEqual(floatToFloat16( 50.0), Float16( 50.0).bytes)
        XCTAssertEqual(floatToFloat16( 25.0), Float16( 25.0).bytes)
        XCTAssertEqual(floatToFloat16( 10.0), Float16( 10.0).bytes)
        XCTAssertEqual(floatToFloat16(  2.0001), Float16(  2.0001).bytes)
        XCTAssertEqual(floatToFloat16(  2.0), Float16(  2.0).bytes)
        XCTAssertEqual(floatToFloat16(  1.999), Float16(  1.999).bytes)
        XCTAssertEqual(floatToFloat16(  1.0), Float16(  1.0).bytes)
        XCTAssertEqual(floatToFloat16(  0.5), Float16(  0.5).bytes)
        XCTAssertEqual(floatToFloat16(  0.2), Float16(  0.2).bytes)
        XCTAssertEqual(floatToFloat16(  0.125), Float16(  0.125).bytes)
        XCTAssertEqual(floatToFloat16(  0.1), Float16(  0.1).bytes)
        XCTAssertEqual(floatToFloat16(  0.0), Float16(  0.0).bytes)
        XCTAssertEqual(floatToFloat16( -0.0), Float16( -0.0).bytes)

        XCTAssertEqual(floatToFloat16(  -0.5), Float16(  -0.5).bytes)
        XCTAssertEqual(floatToFloat16( -10.0), Float16( -10.0).bytes)
        XCTAssertEqual(floatToFloat16(-100.0), Float16(-100.0).bytes)
    }
    
    func testF16ToFloat () {
        XCTAssertEqual(float16ToFloat(Float16( 100.0).bytes), 100.0)
        XCTAssertEqual(float16ToFloat(Float16(  50.0).bytes),  50.0)
        XCTAssertEqual(float16ToFloat(Float16(  25.0).bytes),  25.0)
        XCTAssertEqual(float16ToFloat(Float16(  10.0).bytes),  10.0)
        
        XCTAssertEqual(float16ToFloat(Float16( 2.001).bytes), 2.001, accuracy: 0.001)
        XCTAssertEqual(float16ToFloat(Float16( 2.000).bytes), 2.000, accuracy: 0.001)
        XCTAssertEqual(float16ToFloat(Float16( 1.999).bytes), 1.999, accuracy: 0.001)

        XCTAssertEqual(float16ToFloat(Float16(   1.0).bytes),   1.0)
        XCTAssertEqual(float16ToFloat(Float16(   0.5).bytes),   0.5)
        XCTAssertEqual(float16ToFloat(Float16(   0.2).bytes),   0.2, accuracy: 0.001)
        XCTAssertEqual(float16ToFloat(Float16( 0.125).bytes), 0.125, accuracy: 0.001)
        XCTAssertEqual(float16ToFloat(Float16(   0.1).bytes),   0.1, accuracy: 0.001)

        XCTAssertEqual(float16ToFloat(Float16(   0.0).bytes),   0.0)
        XCTAssertTrue (float16ToFloat(Float16(   0.0).bytes).sign == .plus)

        XCTAssertEqual(float16ToFloat(Float16(  -0.0).bytes),  -0.0)
        XCTAssertTrue (float16ToFloat(Float16(  -0.0).bytes).sign == .minus)

        XCTAssertEqual(float16ToFloat(Float16(  -0.5).bytes),  -0.5)
        XCTAssertEqual(float16ToFloat(Float16( -10.0).bytes), -10.0)
        XCTAssertEqual(float16ToFloat(Float16(-100.0).bytes),-100.0)
    }
    
#endif
}

#if arch(arm64)
// on Arm64 (Apple Silicon), we can test our Float16 <-> Float routines against the native ones
extension Float16 {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }
}
#endif
