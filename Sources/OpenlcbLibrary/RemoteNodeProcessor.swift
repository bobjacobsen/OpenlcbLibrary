//
//  RemoteNodeProcessor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Handle incoming messages for a remote node, AKA an image node, representing some
/// physical node out on the layout.
struct RemoteNodeProcessor : Processor {
    public func process( _ message : Message, _ node : Node) {
        switch message.mti {
        case .InitializationComplete :
            initializationComplete(message, node)
        case .ProtocolSupportReply :
            protocolSupportReply(message, node)
        default:
             break
        }
    }
    
    // TODO: needs to check destination before changing state in Node
    
    private func initializationComplete(_ message : Message, _ node : Node) {
        if checkDestID(message, node) {
            node.state = Node.State.Initialized
        }
    }
    
    private func protocolSupportReply(_ message : Message, _ node : Node) {
        if checkDestID(message, node) {
            let part0 : Int = (message.data.count > 0) ? (Int(message.data[0]) << 24) : 0
            let part1 : Int = (message.data.count > 1) ? (Int(message.data[1]) << 16) : 0
            let part2 : Int = (message.data.count > 2) ? (Int(message.data[2]) <<  8) : 0
            let part3 : Int = (message.data.count > 3) ? (Int(message.data[3])      ) : 0
            let content : UInt32 =  UInt32(part0|part1|part2|part3)
            node.pipSet = PIP.contains(content)
        }
    }
    
    private func checkDestID(_ message : Message, _ node : Node) -> Bool {
        return message.destination == node.nodeID
    }
}
