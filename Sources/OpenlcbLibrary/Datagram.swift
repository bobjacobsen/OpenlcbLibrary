//
//  Datagram.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

struct Datagram : Equatable {
    let source : Node
    let destination : Node
    let data : [UInt8]

    enum DatagramProtocolID : UInt {
        case LogRequest     = 0x01
        case LogReply       = 0x02
        
        case MemoryOperation = 0x20
        
        case RemoteButton   = 0x21
        case Display        = 0x28
        case TrainControl   = 0x30
        
        case Unrecognized   = 0xFFF // 12 bits: out of possible normal range
    }

    /// Returns Unrecognized if there is no type specified, i.e. the datagram is empty
    func datagramType() -> DatagramProtocolID {
        if (data.count == 0) { return .Unrecognized }
        if let retval = DatagramProtocolID(rawValue: UInt(data[0])) {
            return retval
        } else {
            return .Unrecognized
        }
    }

}

