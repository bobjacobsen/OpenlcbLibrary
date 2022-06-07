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
    }

}

