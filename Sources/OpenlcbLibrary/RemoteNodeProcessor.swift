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
        case .Initialization_Complete, .Initialization_Complete_Simple :
            initializationComplete(message, node)
        case .Protocol_Support_Reply :
            protocolSupportReply(message, node)
        case .Link_Level_Up :
            linkUpMessage(message, node)
        case .Link_Level_Down :
            linkDownMessage(message, node)
        case .Simple_Node_Ident_Info_Request :
            simpleNodeIdentInfoRequest(message, node)
        case .Simple_Node_Ident_Info_Reply :
            simpleNodeIdentInfoReply(message, node)
        // TODO: Event Protocol messages - record in local event store
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
        // don't clear out PIP, SNIP caches, they're probably still good
        // node.pipSet = Set<PIP>()
        // node.snip = SNIP()
    }

    private func linkDownMessage(_ message : Message, _ node : Node) {
        // affects everybody
        node.state = Node.State.Uninitialized
        // don't clear out PIP, SNIP caches, they're probably still good
        // node.pipSet = Set<PIP>()
        // node.snip = SNIP()
    }

    private func protocolSupportReply(_ message : Message, _ node : Node) {
        if checkSourceID(message, node) { // send by us?
            let part0 : Int = (message.data.count > 0) ? (Int(message.data[0]) << 24) : 0
            let part1 : Int = (message.data.count > 1) ? (Int(message.data[1]) << 16) : 0
            let part2 : Int = (message.data.count > 2) ? (Int(message.data[2]) <<  8) : 0
            let part3 : Int = (message.data.count > 3) ? (Int(message.data[3])      ) : 0
            let content : UInt32 =  UInt32(part0|part1|part2|part3)
            node.pipSet = PIP.setContents(content)
        }
    }
    
    private func simpleNodeIdentInfoRequest(_ message : Message, _ node : Node) {
        // clear SNIP in the node
        node.snip = SNIP()
    }
    
    private func simpleNodeIdentInfoReply(_ message : Message, _ node : Node) {
        // accumulate data in the node
        if message.data.count > 2 {
            node.snip.addData(data: message.data)
            node.snip.updateStringsFromSnipData()
        }
    }
    
    private func checkSourceID(_ message : Message, _ node : Node) -> Bool {
        return message.source == node.id
    }
}
