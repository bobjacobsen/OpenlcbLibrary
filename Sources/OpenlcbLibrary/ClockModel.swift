//
//  ClockModel.swift
//  
//
//  Created by Bob Jacobsen on 7/12/22.
//

import Foundation

/// Store and maintain the status of a clock, real time or fast.
///
/// Works with ``ClockProcessor`` which handles the OpenLCB network interactions.
///
/// Interface is via Date objects so that hours and minutes etc can be passed simultaneously.
///
/// Service routines are provided to convert from/to hours and minutes.
final public class ClockModel : ObservableObject {
    // Internal date and time throughout use the default UTC timezone; so long as that's used consistently,
    // it avoids issues with properly selecting the local timezone if operating remotely.

    var processor : ClockProcessor? = nil  // will be initialized in network initialization
    
    @Published public var showingControlSheet = false  // used to determine whether the control sheet is visible on macOS
    
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
    internal var internalRun = true  // Starts as true to make real-time clock if no actual clock on bus
                                     // LCC fasts clock will override on 1st access

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
    
    /// Sets the current time in the local clock.  This is generally set from the
    /// clock master.
    ///
    /// Default argument is the usual case; argument is
    /// provided for testing.
    public func setTime(_ time: Date, _ now : Date = Date()) {
        // This structure prevents Time
        // from being a computed property.
        lastTimeSet = time
        timeLastSet = now
    }
    
    /// Gets the current time in the clock. Default argument is the usual case; argument is
    /// provided for testing.
    public func getTime(_ now : Date = Date()) -> Date {
        //  This structure prevents Time
        //  from being a computed property.
        if run {
            return lastTimeSet+(now-timeLastSet)*rate
        } else {
            return lastTimeSet
        }
    }
    
    /// Set the time in the master clock.  Normally, this will then
    /// propagate back via the OpenLCB network to the local clock.
    public func setTimeInMaster(to newTime: Date) {
        processor!.sendSetTime(getHour(newTime), getMinute(newTime))
    }
    
    /// Set the run state in the master clock.  Normally, this will then
    /// propagate back via the OpenLCB network to the local clock.
    public func setRunStateInMaster(to newRun: Bool) {
        processor!.sendSetRunState(to: newRun)
    }
    
    /// Set the run rate in the master clock.  Normally, this will then
    /// propagate back via the OpenLCB network to the local clock.
    public func setRunRateInMaster(to newRate: Double) {
        processor!.sendSetRunRate(to: newRate)
    }
    
    /// Update the internal calculation so that it
    /// propagates forward from now.
    ///
    /// Used when e.g. the rate changes to base future calculations properly.
    ///
    /// Default arguments are the usual case; argument is
    /// provided for testing.
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

// provide a "-" subtraction operator for times:
//   Date - Date = TimeInterval
//  see: https://stackoverflow.com/questions/50950092/calculating-the-difference-between-two-dates-in-swift

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
}
