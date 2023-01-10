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
    var clock0 = ClockModel()
    var clock1 = ClockModel()
    var processor : Processor = ClockProcessor(nil, nil, [])
        
    override func setUpWithError() throws {
        node21 = Node(NodeID(21))
        clock0 = ClockModel()
        clock1 = ClockModel()
        processor = ClockProcessor(nil, nil, [clock0, clock1])
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testRunStop() {
        clock0.run = false
        let msg1 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 0xF0,02]) // start
        _ = processor.process(msg1, node21)
        XCTAssertEqual(clock0.run, true, "clock started")
        let msg2 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 0xF0,01]) // stop
        _ = processor.process(msg2, node21)
        XCTAssertEqual(clock0.run, false, "clock stopped")
    }

    func testSetTimeAndDate() {
        let msg1 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, UInt8(0x30+2020/256), UInt8(2020&0xff)]) // year 2020
        _ = processor.process(msg1, node21)
        let msg2 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 0x22,23]) // Feb 23
        _ = processor.process(msg2, node21)
        let msg3 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 12, 34]) // 12:34
        _ = processor.process(msg3, node21)

        let setTime = clock0.getTime()
        XCTAssertEqual(clock0.getYear(setTime), 2020)
        XCTAssertEqual(clock0.getMonth(setTime), 2)
        XCTAssertEqual(clock0.getDay(setTime), 23)
        XCTAssertEqual(clock0.getHour(setTime), 12)
        XCTAssertEqual(clock0.getMinute(setTime), 34)
    }

    func testInvalidClockNumber() {
        let c1 = clock1.getTime()
        let c0 = clock0.getTime()
        
        let msg1 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,4, UInt8(0x30+2020/256), UInt8(2020&0xff)]) // year 2020, but invalid clock number
        _ = processor.process(msg1, node21)
        
        XCTAssertEqual(clock0.getTime().description, c0.description)
        XCTAssertEqual(clock1.getTime().description, c1.description)
    }
    
    func testSetRate() {
        let msg1 = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(13), data: [1,1,0,0,1,0, 0x40, 16]) // rate 4
        _ = processor.process(msg1, node21)
        
        XCTAssertEqual(clock0.rate, 4.0)
    }
    

}
