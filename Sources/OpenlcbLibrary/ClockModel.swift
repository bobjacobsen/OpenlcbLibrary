//
//  ClockModel.swift
//  
//
//  Created by Bob Jacobsen on 7/12/22.
//

import Foundation
#if os(iOS)
import UIKit        // for check of iPhone vs iPad
import WatchConnectivity
#endif
import os

/// Store and maintain the status of a clock, real time or fast.
///
/// Works with ``ClockProcessor`` which handles the OpenLCB network interactions.
///
/// Interface is via Date objects so that hours and minutes etc can be passed simultaneously.
///
/// Service routines are provided to convert from/to hours and minutes.
final public class ClockModel : ObservableObject {
    // Internal date and time throughout use the default UTC timezone; so long as that's used consistently,
    // it avoids issues with properly selecting the local timezone when operating remotely.
    
    var processor : ClockProcessor? = nil  // will be initialized in network initialization
    
    public init() {
        calendar = Calendar.current
    }
    internal var calendar : Calendar
    
    static let logger = Logger(subsystem: "us.ardenwood.OlcbLibDemo", category: "ClockModel")
    
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
    
    /// Update time from a UI, using current year/month/day
    ///  Returns resulting hour and minute as ints, including 24/60 truncation if needed
    public func updateTime(hour: Int, minute : Int ) -> (String, String) {
        let currentDate = getTime()
        // create a new Date from components
        var dateComponents = DateComponents()
        dateComponents.year = getYear(currentDate)
        dateComponents.month = getMonth(currentDate)
        dateComponents.day = getDay(currentDate)
        // dateComponents.timeZone = currentDate.timeZone
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = Int(0)
        let userCalendar = Calendar(identifier: .gregorian) // since the components above (like year 1980) are for Gregorian
        let newDate = userCalendar.date(from: dateComponents)
        setTimeInMaster(to: newDate!)
        if let tempDate = newDate {
            setTime(tempDate)
            var tempMinutes = String(Calendar.current.component(.minute, from: tempDate))
            if tempMinutes.count < 2 { tempMinutes = "0" + tempMinutes }
            return (String(Calendar.current.component(.hour, from: tempDate)), tempMinutes)
        }
        // date unwrap failed
        return ("0", "0")
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
        if !newRun {
            // save current time state for later
            lastTimeSet = getTime()
            timeLastSet = Date() // now
        }
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
        lastTimeSet = time ?? getTime() // getTime uses these values
        timeLastSet = now ?? Date()
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

    public func updateCompanionApp() {
#if os(iOS)
        if WCSession.default.activationState == .activated {
            let context : [String : Any] = ["rate": rate, "run": run,
                                            "lastTimeSet": lastTimeSet,
                                            "timeLastSet": timeLastSet]
            do {
                try WCSession.default.updateApplicationContext(context)
            } catch {
                ClockModel.logger.error("Catch from updateApplicationContext")
            }
        } else {
            if UIDevice.current.userInterfaceIdiom == .phone { // not expected to work on iPad
                ClockModel.logger.warning("WCSession not activated in updateCompanionApp")
            }
        }
#endif
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
