//
//  EventID.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Represents an 8-byte event ID.
///  Provides conversion to and from Ints and Strings in standard form.
public struct EventID : Equatable, Hashable, Comparable, CustomStringConvertible {
    public let eventID : UInt64 // to ensure 8 byte EventID)
    
    /// Display in standard format
    public var description : String {
        let bytes = toArray()
        return  "\(String(format:"%02X", bytes[0]))." +
                "\(String(format:"%02X", bytes[1]))." +
                "\(String(format:"%02X", bytes[2]))." +
                "\(String(format:"%02X", bytes[3]))." +
                "\(String(format:"%02X", bytes[4]))." +
                "\(String(format:"%02X", bytes[5]))." +
                "\(String(format:"%02X", bytes[6]))." +
                "\(String(format:"%02X", bytes[7]))"
    }
    
    /// Convert an integer to an eventID
    ///
    /// Need to be UInt64 input because an eventID is an 8-byte quantity, and uses the top bit apart from a sign.
    public init(_ eventID : UInt64) {
        self.eventID = eventID
    }
    
    /// Convert a standard-format string 08.09.0A.0B.0C.0D.0E.0F to an eventID
    ///
    /// Leading zeros can be omitted. Accepts truncated values - left fills with zeros. Also accepts single large hex number.
    public init(_ eventID : String) {
        let components = eventID.components(separatedBy: ".")
        var result : UInt64 = 0
        for component in components {
            let pieceValue = UInt64(component, radix: 16) ?? 0
            result = result << 8 | pieceValue
        }
        self.eventID = result
    }
    
    /// Convert data bytes to eventID
    ///
    /// Missing/truncated values are assumed to be zero.
    public init(_ data : [UInt8]) {
        var eventID : UInt64 = 0
        if (data.count > 0) {eventID |= UInt64(data[0] & 0xFF) << 56}
        if (data.count > 1) {eventID |= UInt64(data[1] & 0xFF) << 48}
        if (data.count > 2) {eventID |= UInt64(data[2] & 0xFF) << 40}
        if (data.count > 3) {eventID |= UInt64(data[3] & 0xFF) << 32}
        if (data.count > 4) {eventID |= UInt64(data[4] & 0xFF) << 24}
        if (data.count > 5) {eventID |= UInt64(data[5] & 0xFF) << 16}
        if (data.count > 6) {eventID |= UInt64(data[6] & 0xFF) <<  8}
        if (data.count > 7) {eventID |= UInt64(data[7] & 0xFF)      }
        self.init(eventID)
    }
    
    public func toArray() -> [UInt8] {
        return [
            UInt8( (eventID >> 56 ) & 0xFF ),
            UInt8( (eventID >> 48 ) & 0xFF ),
            UInt8( (eventID >> 40 ) & 0xFF ),
            UInt8( (eventID >> 32 ) & 0xFF ),
            UInt8( (eventID >> 24 ) & 0xFF ),
            UInt8( (eventID >> 16 ) & 0xFF ),
            UInt8( (eventID >>  8 ) & 0xFF ),
            UInt8( (eventID       ) & 0xFF )
        ]
    }
    
    // Comparable is defined on the ID
    public static func <(lhs: EventID, rhs: EventID) -> Bool {
        return lhs.eventID < rhs.eventID
    }

}

