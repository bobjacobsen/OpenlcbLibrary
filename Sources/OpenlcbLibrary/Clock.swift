//
//  Clock.swift
//  
//
//  Created by Bob Jacobsen on 7/12/22.
//

import Foundation

// Store and maintain the status of a clock, real time or fast.
//
// Interface is via Date objects to that hours and minutes etc can be passed simultaneously.
//  Service routines are provided to convert from/to hours and minutes.
// TODO: Add day and year convenience methods
final public class Clock : ObservableObject {
    internal var initialized = false
    
    internal var internalRun = true  // TODO: what should this start as?
    public var run: Bool {
        get { return internalRun }
        set(run) {
            updateTimeCalculation()
            internalRun = run
        }
    }
    
    internal var internalRate = 10.0   // TODO: what should this start as?
    public var rate: Double {
        get { return internalRate }
        set(rate) {
            updateTimeCalculation()
            internalRate = rate
        }
    }

    
    // fast fime is lastTimeSet+(now-timeLastSet)*rate
    private var timeLastSet = Date()  // default is now
    private var lastTimeSet = Date()  // default is now
    
    // Default argument is the usual case; argument is
    // provided for testing. This structure prevents this
    // from being a computed property.
    public func setTime(_ time: Date, _ now : Date = Date()) {
        lastTimeSet = time
        timeLastSet = now
    }
    
    // Default argument is the usual case; argument is
    // provided for testing. This structure prevents this
    // from being a computed property.
    public func getTime(_ now : Date = Date()) -> Date {
        if run {
            return lastTimeSet+(now-timeLastSet)*rate
        } else {
            return lastTimeSet
        }
    }
    
    // Update the internal calculation so that it
    // propagates forward from now.
    //
    // Used when e.g. the rate changes to base future calculations properly.
    //
    // Default arguments are the usual case; argument is
    // provided for testing.
    private func updateTimeCalculation(time: Date? = nil, now: Date? = nil ) {
        timeLastSet = now ?? Date()
        lastTimeSet = time ?? getTime()
    }
    
    // convenience methods - NOT atomic, prefer getTime for accuracy,
    // or do e.g. date = clock.getDate(); hour = clock.getHour(date); minute = clock.getMinute(date);
    public func getMinute(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return Calendar.current.component(.minute, from:date)
        } else { // date not provided, use current fast time from getTime()
            return Calendar.current.component(.minute, from:getTime())
        }
    }
    public func getHour(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return Calendar.current.component(.hour, from:date)
        } else { // date not provided, use current fast time from getTime()
            return Calendar.current.component(.hour, from:getTime())
        }
    }
    public func getSecond(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return Calendar.current.component(.second, from:date)
        } else { // date not provided, use current fast time from getTime()
            return Calendar.current.component(.second, from:getTime())
        }
    }

}

// provide a - operator for times:
//   Date - Date = TimeInterval
//  see: https://stackoverflow.com/questions/50950092/calculating-the-difference-between-two-dates-in-swift

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
}
