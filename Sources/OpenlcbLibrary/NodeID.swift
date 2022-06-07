//
//  NodeID.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Represents a 6-byte node ID.
///  Provides conversion to and from Ints and Strings in standard form.
public struct NodeID : Equatable, Hashable, CustomStringConvertible {
    let nodeID : UInt64 // to ensure 6 byte ID (analogy to 8 byte EventID)
    
    /// Display in standard format
    public var description : String {
        let part1 = (nodeID / 0x01_00_00_00_00_00 ) & 0xFF
        let part2 = (nodeID / 0x00_01_00_00_00_00 ) & 0xFF
        let part3 = (nodeID / 0x00_00_01_00_00_00 ) & 0xFF
        let part4 = (nodeID / 0x00_00_00_01_00_00 ) & 0xFF
        let part5 = (nodeID / 0x00_00_00_00_01_00 ) & 0xFF
        let part6 = (nodeID / 0x00_00_00_00_00_01 ) & 0xFF
        
        return "NodeID " +
        "\(String(format:"%02X", part1))." +
        "\(String(format:"%02X", part2))." +
        "\(String(format:"%02X", part3))." +
        "\(String(format:"%02X", part4))." +
        "\(String(format:"%02X", part5))." +
        "\(String(format:"%02X", part6))"
    }
    
    /// Convert an integer to a NodeID
    public init(_ nodeID : UInt64) {
        self.nodeID = nodeID
    }
    
    /// Convert a standard-format string 0A.0B.0C.0D.0E.0F to a NodeID
    public init(_ nodeID : String) {
        let hex = nodeID.replacingOccurrences(of: ".", with: "")
        self.nodeID = UInt64(hex, radix: 16) ?? 0
    }
}

