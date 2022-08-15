//
//  Clock.swift
//  
//
//  Created by Bob Jacobsen on 7/12/22.
//

import Foundation

/// Store and maintain the status of a clock, real time or fast.
///
/// Works with `ClockProcessor` which handles the OpenLCB network interactions

// Interface is via Date objects to that hours and minutes etc can be passed simultaneously.
//  Service routines are provided to convert from/to hours and minutes.
//
// Internal date and time throughout use the default UTC timezone; so long as that's used consistently,
// it avoids issues with properly selecting the local timezone if operating remotely.

final public class Clock : ObservableObject {
    
    public init() {
        calendar = Calendar.current
    }
    internal var calendar : Calendar
    
    /// 'run' determines whetther the clock is running or not.  This is generally set from the
    ///  clock master.
    public var run: Bool {
        get { return internalRun }
        set(run) {
            updateTimeCalculation()
            internalRun = run
        }
    }
    internal var internalRun = true  // TODO: what should this start as?

    /// 'rate' determines the rate at which the clock advances.  This is generally set from the
    ///  clock master.
    public var rate: Double {
        get { return internalRate }
        set(rate) {
            updateTimeCalculation()
            internalRate = rate
        }
    }
    internal var internalRate = 1.0

    
    // fast fime is lastTimeSet+(now-timeLastSet)*rate
    private var timeLastSet = Date()  // default is now
    private var lastTimeSet = Date()  // default is now
    
    /// Sets the current time in the clock.  This is generally set from the
    /// clock master.
    // Default argument is the usual case; argument is
    // provided for testing. This structure prevents this
    // from being a computed property.
    public func setTime(_ time: Date, _ now : Date = Date()) {
        lastTimeSet = time
        timeLastSet = now
    }
    
    /// Gets the current time in the clock.  
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
    public func getYear(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return calendar.component(.year, from:date)
        } else { // date not provided, use current fast time from getTime()
            return calendar.component(.year, from:getTime())
        }
    }
    public func getMonth(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return calendar.component(.month, from:date)
        } else { // date not provided, use current fast time from getTime()
            return calendar.component(.month, from:getTime())
        }
    }
    public func getDay(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return calendar.component(.day, from:date)
        } else { // date not provided, use current fast time from getTime()
            return calendar.component(.day, from:getTime())
        }
    }
    public func getHour(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return calendar.component(.hour, from:date)
        } else { // date not provided, use current fast time from getTime()
            return calendar.component(.hour, from:getTime())
        }
    }
    public func getMinute(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return calendar.component(.minute, from:date)
        } else { // date not provided, use current fast time from getTime()
            return calendar.component(.minute, from:getTime())
        }
    }
    public func getSecond(_ date : Date? = nil) -> Int {
        if let date { // date was provided, use it
            return calendar.component(.second, from:date)
        } else { // date not provided, use current fast time from getTime()
            return calendar.component(.second, from:getTime())
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
