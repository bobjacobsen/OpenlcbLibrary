//
//  EventID.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Represents an 8-byte node ID.
///  Provides conversion to and from Ints and Strings in standard form.
public struct EventID : Equatable, Hashable, CustomStringConvertible {
    let eventID : UInt64 // to ensure 8 byte EventID)
    
    /// Display in standard format
    public var description : String {
        let part1 = (eventID / 0x01_00_00_00_00_00_00_00 ) & 0xFF
        let part2 = (eventID / 0x00_01_00_00_00_00_00_00 ) & 0xFF
        let part3 = (eventID / 0x00_00_01_00_00_00_00_00 ) & 0xFF
        let part4 = (eventID / 0x00_00_00_01_00_00_00_00 ) & 0xFF
        let part5 = (eventID / 0x00_00_00_00_01_00_00_00 ) & 0xFF
        let part6 = (eventID / 0x00_00_00_00_00_01_00_00 ) & 0xFF
        let part7 = (eventID / 0x00_00_00_00_00_00_01_00 ) & 0xFF
        let part8 = (eventID / 0x00_00_00_00_00_00_00_01 ) & 0xFF
        
        return "EventID " +
        "\(String(format:"%02X", part1))." +
        "\(String(format:"%02X", part2))." +
        "\(String(format:"%02X", part3))." +
        "\(String(format:"%02X", part4))." +
        "\(String(format:"%02X", part5))." +
        "\(String(format:"%02X", part6))." +
        "\(String(format:"%02X", part7))." +
        "\(String(format:"%02X", part8))"
    }
    
    /// Convert an integer to a NodeID
    public init(_ nodeID : UInt64) {
        self.eventID = nodeID
    }
    
    /// Convert a standard-format string 08.09.0A.0B.0C.0D.0E.0F to a NodeID
    public init(_ eventID : String) {
        let hex = eventID.replacingOccurrences(of: ".", with: "")
        self.eventID = UInt64(hex, radix: 16) ?? 0
    }
}

