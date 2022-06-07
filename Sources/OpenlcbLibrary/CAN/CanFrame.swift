//
//  File.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

public struct CanFrame : Equatable, CustomStringConvertible {
    var header : UInt
    var data : [UInt8]
    
    public var description : String { "CanFrame header: \(String(format:"%08X", header)) ) \(data)" }

    init(header : UInt, data : [UInt8] ) {
        self.header = header
        self.data = data
    }
    
    /// Create the Nth CID frame
    init(cid : Int, nodeID: NodeID, alias : UInt) {
        // cid must be 4 to 7 inclusive
        precondition(4 <= cid && cid <= 7)
        
        let nodeCode = UInt( ( nodeID.nodeID >> ((cid-4)*12) ) & 0xFFF )
        header = (UInt(cid << 12) | nodeCode) << 12 | (alias & 0xFFF)
        data = []
    }
    
    /// Create control frame (other than CID)
    init(control : Int, alias : UInt) {  // TODO: needs to have optional NodeID in data
        header = UInt(control << 12) | (alias & 0xFFF)
        data = []
    }
}
