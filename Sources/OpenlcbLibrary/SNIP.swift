//
//  SNIP.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

/// Holds the Simple Node Information Protocol values or blank strings.
///
/// Provides support for loading via short or long messages. A SNIP is write-once; when the underlying
/// connection resets, a new SNIP struct should be installed in the node.
public struct SNIP {

    // The values of these are updated as more data comes in so othat they're
    // always the best available names.
    public internal(set) var manufacturerName = ""
    public internal(set) var modelName = ""
    public internal(set) var hardwareVersion = ""
    public internal(set) var softwareVersion = ""
    
    public internal(set) var userProvidedNodeName = ""
    public internal(set) var userProvidedDescription = ""

    // total SNIP data is 1+41+41+21+21 1+63+64 = 125+128 = 253 bytes
    internal var data : [UInt8] = Array(repeating: 0, count: 253)
    internal var index = 0; // for loading in multiple messages
    
    public init() {}
    public init(_ mfgName : String, // for debug and SwiftUI preview
                _ model : String,
                _ hVersion : String,
                _ sVersion : String,
                _ uName : String,
                _ uDesc : String) {
        manufacturerName = mfgName
        modelName = model
        hardwareVersion = hVersion
        softwareVersion = sVersion
        userProvidedNodeName = uName
        userProvidedDescription = uDesc
    }
    
     // OLCB Strings are fixed length null terminated.
     // We don't (yet) support later versions with e.g. larger strings, etc.

    /// Get the desired string by string number in the data.
    /// - Parameter n: 0-based number of the String
    /// - Returns: Requested String up to but not including the terminating zero byte
    func getString(n : Int) -> String {
        let start = findString(n: n)
        var len = 0
        switch n {
        case 0,1 :
            len = 41
        case 2,3 :
            len = 21
        case 4 :
            len = 63
        case 5 :
            len = 64
        default :
            SNIP.logger.error("Unexpected string request: \(n)")
            return ""
        }
        return getString(first: start, maxLength: len)
    }
    ///  FInd start index of the nth string.
    ///
    ///  Zero indexed.
    ///  Is aware of the 2nd version code byte.
    ///  Logs and returns -1 if the string isn't found withn the buffer
    func findString(n : Int) -> Int {
        if n == 0 {
            return 1 // first one is automatic
        }
        var retval = 1
        var stringCount = 0
        // scan over the buffer
        for var i in 1...252 {
            // checking for an end-of-string mark
            if data[i] == 0 {
                // found one - this ends the stringCount string
                // if that's the request, return start
                if stringCount == n {
                    return retval
                }
                // if not, the _next_ character starts the next string
                retval = i+1
                stringCount += 1
                // special case for the 5th string
                if stringCount == 4 {
                    i += 1
                    retval += 1
                }
            }
        }
        // fell out without finding
        return 0
    }
    
    ///  Retrieve a string from a starting byte index and largest possible length
    ///
    ///   The `maxLength` parameter prevents overflow
    func getString(first : Int, maxLength : Int) -> String {
        var last = first
        while (last < first+maxLength) {
            if (data[last]) == 0 {
                break
            } else {
                last += 1
            }
        }
        // last should point at the first zero or last location
        if (first == last) {
            return ""
        }
        if let retval = String(bytes: data[first...last-1], encoding: .utf8) {
            return retval
        } else {
            SNIP.logger.error("String failed UTF-8 conversion")
            return ""
        }
    }
    
    /// Add additional bytes of SNIP data
    mutating func addData(data : [UInt8] ) {
        for i in 0...data.count-1 {
            // protect against overlapping requests causing an overflow
            if (i+index) >= 253 {
                SNIP.logger.error("Overlapping SNIP requests, truncating")
                break
            }
            self.data[i+index] = data[i]
        }
        index += data.count
        updateStringsFromSnipData()
    }
    
    // load strings from current SNIP accumulated data
    mutating func updateStringsFromSnipData() {
        manufacturerName =  getString(n: 0)
        modelName =         getString(n: 1)
        hardwareVersion =   getString(n: 2)
        softwareVersion =   getString(n: 3)
        
        userProvidedNodeName = getString(n: 4)
        userProvidedDescription = getString(n: 5)
    }
    
    // store strings into SNIP accumulated data
    mutating func updateSnipDataFromStrings() {
        // clear string
        data = Array(repeating: 0, count: 253)
        
        var index = 1 // next storage location
        data[0] = 4 // first part version
        
        let mfgArray = Data(manufacturerName.utf8.prefix(40))  // leave one space for zero
        if (mfgArray.count>0) {
            for i in 0...mfgArray.count-1 { data[index] = mfgArray[i]; index+=1}
        }
        data[index] = 0; index += 1
        
        let mdlArray = Data(modelName.utf8.prefix(40))
        if (mdlArray.count>0) {
            for i in 0...mdlArray.count-1 { data[index] = mdlArray[i]; index+=1}
        }
        data[index] = 0; index += 1
        
        let hdvArray = Data(hardwareVersion.utf8.prefix(20))
            if (hdvArray.count>0) {
            for i in 0...hdvArray.count-1 { data[index] = hdvArray[i]; index+=1}
        }
        data[index] = 0; index += 1
        
        let sdvArray = Data(softwareVersion.utf8.prefix(20))
        if (sdvArray.count>0) {
            for i in 0...sdvArray.count-1 { data[index] = sdvArray[i]; index+=1}
        }
        data[index] = 0; index += 1
        
        data[index] = 2; index += 1
        
        let upnArray = Data(userProvidedNodeName.utf8.prefix(62))
        if (upnArray.count>0) {
            for i in 0...upnArray.count-1 { data[index] = upnArray[i]; index+=1}
        }
        data[index] = 0; index += 1
        
        let updArray = Data(userProvidedDescription.utf8.prefix(63))
        if (updArray.count>0) {
            for i in 0...updArray.count-1 { data[index] = updArray[i]; index+=1}
        }
        data[index] = 0; index += 1
    }
    
    func returnStrings() -> [UInt8] {
        // copy out until the 6th zero byte
        let stop = findString(n: 6)
        var retval : [UInt8] = Array(repeating: 0, count: stop)
        if (stop == 0) { return retval }
        for i in 0 ... stop-1 {
            retval[i] = data[i]
        }
        return retval
    }
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "SNIP")
}
