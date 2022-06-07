//
//  Message.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Represents the basic message, with an MTI, source, destination? and data content.
public struct Message : Equatable, Hashable, CustomStringConvertible {
    let mti : MTI
    let source : NodeID
    let destination : NodeID?
    var data : [UInt8]
    
    init(mti : MTI, source : NodeID, destination : NodeID?) {
        self.mti = mti
        self.source = source
        self.destination = destination
        self.data = []
    }
    
    init(mti : MTI, source : NodeID) {
        self.init(mti: mti, source : source, destination : nil)
    }
    
    public var description : String { "Message (\(mti))"}

    /// data can vary, so not included in hash
    public func hash(into hasher : inout Hasher) {
        hasher.combine(mti)
        hasher.combine(source)
        hasher.combine(destination)
    }
}
