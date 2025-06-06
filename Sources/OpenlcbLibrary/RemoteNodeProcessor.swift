//
//  RemoteNodeProcessor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

/// Handle incoming messages for a remote node, AKA an image node, representing some
/// physical node out on the layout.
///
/// Tracks node status, PIP and SNIP information, but deliberately does not track memory (config, CDI) contents due to size.
public struct RemoteNodeProcessor : Processor {
    init ( _ linkLayer: CanLink? = nil) {
        self.linkLayer = linkLayer
    }
    
    let linkLayer : CanLink?
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "RemoteNodeProcessor")
    
    public func process( _ message : Message, _ node : Node  ) -> Bool {
        // Do a fast drop of messages not to us, from us, or global - note linkLayer up/down are marked as global
        guard message.mti.isGlobal()
                || checkSourceID(message, node)
                || checkDestID(message, node)
            else { return false }
        
        // if you see anything at all from us, must be in Initialized state
        if checkSourceID(message, node) {  // Sent by node we're processing?
            node.state = Node.State.Initialized // in case we came late to the party, must be in Initialized state
        }
        
        // specific message handling
        switch message.mti {
        case .Initialization_Complete, .Initialization_Complete_Simple :
            initializationComplete(message, node)
            return true
        case .Protocol_Support_Reply :
            protocolSupportReply(message, node)
            return true
        case .Link_Layer_Up :
            linkUpMessage(message, node)
        case .Link_Layer_Down :
            linkDownMessage(message, node)
        case .Simple_Node_Ident_Info_Request :
            simpleNodeIdentInfoRequest(message, node)
        case .Simple_Node_Ident_Info_Reply :
            simpleNodeIdentInfoReply(message, node)
            return true
        case .Producer_Identified_Active, .Producer_Identified_Inactive, .Producer_Identified_Unknown, .Producer_Consumer_Event_Report :
            producedEventIndicated(message, node)
            return true
        case .Consumer_Identified_Active, .Consumer_Identified_Inactive, .Consumer_Identified_Unknown :
            consumedEventIndicated(message, node)
            return true
        case .New_Node_Seen :
            newNodeSeen(message, node)
            return true
        default:
            // we ignore others
            return false
        }
        return false
    }
    
    private func initializationComplete(_ message : Message, _ node : Node) {
        if checkSourceID(message, node) {  // Send by us?
            node.state = Node.State.Initialized
            // clear out PIP, SNIP caches - may have changed while node was offline
            node.pipSet = Set<PIP>()
            node.snip = SNIP()
        }
    }
    
    private func linkUpMessage(_ message : Message, _ node : Node) {
        // affects everybody
        node.state = Node.State.Uninitialized
        // don't clear out PIP, SNIP caches, they're probably still good
    }
    
    private func linkDownMessage(_ message : Message, _ node : Node) {
        // affects everybody
        node.state = Node.State.Uninitialized
        // don't clear out PIP, SNIP caches, they're probably still good
    }
    
    private func newNodeSeen(_ message : Message, _ node : Node) {
        // send pip and snip requests
        let pip = Message(mti: MTI.Protocol_Support_Inquiry, source: linkLayer!.localNodeID, destination: node.id, data: [])
        linkLayer?.sendMessage(pip)
        // We request SNIP data on startup so that we can display node names.  Can consider deferring this is it's a issue on big networks
        let snip = Message(mti: MTI.Simple_Node_Ident_Info_Request, source: linkLayer!.localNodeID, destination: node.id, data: [])
        linkLayer?.sendMessage(snip)
        // we request produced and consumed event IDs
        let eventReq = Message(mti: MTI.Identify_Events_Addressed, source: linkLayer!.localNodeID, destination: node.id, data: [])
        linkLayer?.sendMessage(eventReq)
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
        if checkDestID(message, node) { // sent by us? - overlapping SNIP activity is otherwise confusing
            // clear SNIP in the node to start accumulating
            node.snip = SNIP()
        }
    }
    
    private func simpleNodeIdentInfoReply(_ message : Message, _ node : Node) {
        if checkSourceID(message, node) { // sent by this node? - overlapping SNIP activity is otherwise confusing
            // accumulate data in the node
            if message.data.count > 2 {
                node.snip.addData(data: message.data)
                node.snip.updateStringsFromSnipData()
                // logger.trace("SNIP data added to \(node, privacy: .public)")
            }
        }
    }
    
    private func producedEventIndicated(_ message : Message, _ node : Node) {
        if checkSourceID(message, node) { // produced by this node?
            // make an event id from the data
            let eventID = EventID(message.data)  // takes only first eight bytes from EWP
            // register it
            node.events.produces(eventID)

            if (message.mti == .Event_With_Data) {
                processEWP(message, node)
            }
        }
    }
    
    private func processEWP(_ message : Message, _ node : Node) {
        // decode protocol and process
        if (message.data[0]==0x01 && message.data[1]==0x02) {
            processEwpLocationServices(message, node)
        }
    }

    // TODO: should this be a method a new class that holds the LS information? MetersModel?
    private func processEwpLocationServices(_ message : Message, _ node : Node) {
        // decode and process to meter(s) in the node
        // TODO: Decode location services to meter
    }

    private func consumedEventIndicated(_ message : Message, _ node : Node) {
        if checkSourceID(message, node) { // consumed by this node?
            // make an event id from the data
            let eventID = EventID(message.data)
            // register it
            node.events.consumes(eventID)
        }
    }
    
}
