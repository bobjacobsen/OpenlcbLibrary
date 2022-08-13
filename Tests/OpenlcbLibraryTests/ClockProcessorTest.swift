//
//  ClockProcessorTest.swift
//  
//
//  Created by Bob Jacobsen on 7/12/22.
//

import XCTest
@testable import OpenlcbLibrary

final class ClockProcessorTest: XCTestCase {

    var node21 = Node(NodeID(12))
    var clock0 = Clock()
    var clock1 = Clock()
    var processor : Processor = ClockProcessor(nil, [])
        
    override func setUpWithError() throws {
        node21 = Node(NodeID(21))
        clock0 = Clock()
        clock1 = Clock()
        processor = ClockProcessor(nil, [clock0, clock1])
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // TODO: Rework this test to be run/start event received
    func testRunStop() {
        let msg1 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 0xF0,02]) // start
        processor.process(msg1, node21)
        XCTAssertEqual(clock0.run, true, "clock started")
        let msg2 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 0xF0,01]) // stop
        processor.process(msg2, node21)
        XCTAssertEqual(clock0.run, false, "clock stopped")
    }

    func testSetTimeAndDate() {
        let msg1 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, UInt8(0x30+2020/256), UInt8(2020&0xff)]) // year 2020
        processor.process(msg1, node21)
        let msg2 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 0x22,23]) // Feb 23
        processor.process(msg2, node21)
        let msg3 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 12, 34]) // 12:34
        processor.process(msg3, node21)
        XCTAssertEqual(clock0.getTime().description, "2020-02-23 12:34:00 +0000", "clock time set")
    }

    func testInvalidClockNumber() {
        let c1 = clock1.getTime()
        let c0 = clock0.getTime()
        
        let msg1 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,4, UInt8(0x30+2020/256), UInt8(2020&0xff)]) // year 2020, but invalid clock number
        processor.process(msg1, node21)
        
        XCTAssertEqual(clock0.getTime().description, c0.description)
        XCTAssertEqual(clock1.getTime().description, c1.description)
    }
    
    func testSetRate() {
        let msg1 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 0x40, 16]) // rate 4
        processor.process(msg1, node21)
        
        XCTAssertEqual(clock0.rate, 4.0)
    }
    

}
