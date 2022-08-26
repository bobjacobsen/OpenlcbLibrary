//
//  ClockTest.swift
//  
//
//  Created by Bob Jacobsen on 7/12/22.
//

import XCTest
@testable import OpenlcbLibrary

final class ClockTest: XCTestCase {
    
    let dateFormatter = DateFormatter()

    override func setUpWithError() throws {
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        dateFormatter.timeZone = TimeZone.current
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testInitialState() throws {
        let clock = ClockModel()
        XCTAssertEqual(clock.run, true, "clock starts running")
        XCTAssertEqual(clock.rate, 1.0, "clock starts with rate = 1.0")
    }
    
    func testDateFromComponents() {
        // setup up a specific date and time
        var setComponents    = DateComponents()
        setComponents.year   = 1980
        setComponents.month  = 7
        setComponents.day    = 11
        setComponents.timeZone = TimeZone.current // test in local time zone
        setComponents.hour   = 8
        setComponents.minute = 34
        setComponents.second = 21
        // Create date from components
        let calendar = Calendar.current // user calendar
        let setDateTime = calendar.date(from: setComponents)
        
        // TODO: actually set and get from the Clock object
        let getDateTime = setDateTime!
        
        // now check
        let requestedComponents: Set<Calendar.Component> = [
            .year,
            .month,
            .day,
            .hour,
            .minute,
            .second
        ]
        let getComponents = calendar.dateComponents(requestedComponents, from: getDateTime)
        
        XCTAssertEqual(getComponents.year,  setComponents.year, "clock hour matches")
        XCTAssertEqual(getComponents.month, setComponents.month, "clock hour matches")
        XCTAssertEqual(getComponents.day,   setComponents.day, "clock hour matches")
        XCTAssertEqual(getComponents.hour,  setComponents.hour, "clock hour matches")
        XCTAssertEqual(getComponents.hour,  setComponents.hour, "clock hour matches")
        XCTAssertEqual(getComponents.minute,setComponents.minute, "clock minutes matches")
        XCTAssertEqual(getComponents.second,setComponents.second, "clock minutes matches")
        
        // now that we have a good time, use it to test
        let clock = ClockModel()
        clock.setTime(getDateTime)
        
        // compare string forms to avoid nsec clicks
        XCTAssertEqual(clock.getTime().description, getDateTime.description, "match times")
    }
    
    func testDatesFromStrings() {
        let date1 = dateFormatter.date(from: "1970/01/01 00:00")
        let date2 = dateFormatter.date(from: "1970/01/01 00:00")
        let date3 = dateFormatter.date(from: "1970/01/01 00:01")
        
        XCTAssertEqual(date1, date2, "clock matches")
        XCTAssertNotEqual(date1, date3, "clock doesn't match")
    }
    
    func testSetAndGetClock() {
        let now = dateFormatter.date(from: "2022/01/02 00:00")!
        let setTime = dateFormatter.date(from: "2022/01/02 12:34")!
        
        let clock = ClockModel()
        clock.setTime(setTime, now)
        
        XCTAssertEqual(clock.getTime(now), setTime, "clock matches")
        XCTAssertEqual(clock.getYear(setTime), 2022)
        XCTAssertEqual(clock.getMonth(setTime), 1)
        XCTAssertEqual(clock.getDay(setTime), 2)
        XCTAssertEqual(clock.getHour(setTime), 12)
        XCTAssertEqual(clock.getMinute(setTime), 34)

    }
    
    func testRun1MinuteRate4() {
        let setTime = dateFormatter.date(from: "2022/01/01 12:34")! // which became 4 minutes fast
 
        let clock = ClockModel()
        clock.rate = 4
        clock.run = false
        clock.setTime(setTime)
        
        // wait 3 seconds
        let delayExpectation1 = XCTestExpectation()
        delayExpectation1.isInverted = true
        wait(for: [delayExpectation1], timeout: 2)

        // clock should not advance if not running
        XCTAssertEqual(clock.getTime(), setTime, "clock matches")
        
        // clock should advance if running
        clock.run = true
        
        // wait 3 seconds
        let delayExpectation2 = XCTestExpectation()
        delayExpectation2.isInverted = true
        wait(for: [delayExpectation2], timeout: 2)

        XCTAssertNotEqual(clock.getTime(), setTime, "clock advances")

    }
  
    func testAccessors() {
        let setTime = dateFormatter.date(from: "2022/01/01 12:34")!
        let checkTime = dateFormatter.date(from: "2022/01/01 02:12")!

        let clock = ClockModel()
        clock.rate = 4
        clock.setTime(setTime)
        
        XCTAssertEqual(clock.getMinute(), 34, "minute matches by default")
         XCTAssertEqual(clock.getHour(), 12, "hour matches by default")

        XCTAssertEqual(clock.getMinute(checkTime), 12, "minute matches")
        XCTAssertEqual(clock.getHour(checkTime), 2, "hour matches")
    }

}
