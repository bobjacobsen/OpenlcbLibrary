//
//  RemoteNodeProcessor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Handle incoming messages for a remote node, AKA an image node, representing some
/// physical node out on the layout.
///
/// Tracks node status, PIP and SNIP information, but deliberately does not track memory (config, CDI) contents due to size.
///

// TODO: add producer/consumer tracking?

struct RemoteNodeProcessor : Processor {
    public init ( _ linkLayer: LinkLayer? = nil) {
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer? // TODO: Is this needed? Does this ever send?

    public func process( _ message : Message, _ node : Node  ) {
        // if you see anything at all from us, must be in Initialized state
        if checkSourceID(message, node) {  // Sent by node we're processing?
            node.state = Node.State.Initialized // in case we came late to the party, must be in Initialized state
        }
        
        // specific message handling
        switch message.mti {
        case .InitializationComplete :
            initializationComplete(message, node)
        case .ProtocolSupportReply :
            protocolSupportReply(message, node)
        case .LinkLevelUp :
            linkUpMessage(message, node)
        case .LinkLevelDown :
            linkDownMessage(message, node)
        // TODO: SNIP request (clear cache), reply (accumulate)
        default:
            break
        }
    }
    
    private func initializationComplete(_ message : Message, _ node : Node) {
        if checkSourceID(message, node) {  // Send by us?
            node.state = Node.State.Initialized
            // clear out PIP, SNIP caches
            node.pipSet = Set<PIP>()
            node.snip = SNIP()
        }
    }
    
    private func linkUpMessage(_ message : Message, _ node : Node) {
        // affects everybody
        node.state = Node.State.Uninitialized
        // clear out PIP, SNIP caches
        node.pipSet = Set<PIP>()
        node.snip = SNIP()
    }

    private func linkDownMessage(_ message : Message, _ node : Node) {
        // affects everybody
        node.state = Node.State.Uninitialized
        // clear out PIP, SNIP caches
        node.pipSet = Set<PIP>()
        node.snip = SNIP()
    }

    private func protocolSupportReply(_ message : Message, _ node : Node) {
        if checkSourceID(message, node) { // send by us?
            let part0 : Int = (message.data.count > 0) ? (Int(message.data[0]) << 24) : 0
            let part1 : Int = (message.data.count > 1) ? (Int(message.data[1]) << 16) : 0
            let part2 : Int = (message.data.count > 2) ? (Int(message.data[2]) <<  8) : 0
            let part3 : Int = (message.data.count > 3) ? (Int(message.data[3])      ) : 0
            let content : UInt32 =  UInt32(part0|part1|part2|part3)
            node.pipSet = PIP.contains(content)
        }
    }
    
    private func checkSourceID(_ message : Message, _ node : Node) -> Bool {
        return message.source == node.id
    }
}
