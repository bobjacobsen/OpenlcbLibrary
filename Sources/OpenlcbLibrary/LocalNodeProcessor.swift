//
//  LocalNodeProcessor.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

struct LocalNodeProcessor : Processor {
    public init ( _ linkLayer: LinkLayer? = nil) {
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer?
    let logger = Logger(subsystem: "org.ardenwood.OpenlcbLibrary", category: "LocalNodeProcessor")
    
    func process( _ message : Message, _ node : Node ) {
        if ( !checkDestID(message, node) ) { return }  // not to us
        // specific message handling
        switch message.mti {
        case .Link_Level_Up :
            linkUpMessage(message, node)
        case .Link_Level_Down :
            linkDownMessage(message, node)
        case .Verify_NodeID_Number_Global :
            verifyNodeIDNumberGlobal(message, node)
        case .Verify_NodeID_Number_Addressed :
            verifyNodeIDNumberAddressed(message, node)
        case .Protocol_Support_Inquiry :
            protocolSupportInquiry(message, node)
        case .Simple_Node_Ident_Info_Request :
            simpleNodeIdentInfoRequest(message, node)
        case .Identify_Events_Addressed :
            identifyEventsAddressed(message, node)
        case .Terminate_Due_To_Error, .Optional_Interaction_Rejected :
            errorMessageReceived(message, node)
        default:
            unrecognizedMTI(message, node)
            break
        }
        // datagrams and datagram replies are handled in the DatagramProcessor/DatagramService
    }

    private func linkUpMessage(_ message : Message, _ node : Node) {
        node.state = Node.State.Initialized
        let msgIC = Message(mti: MTI.Initialization_Complete, source: node.id, data: node.id.toArray())
        linkLayer!.sendMessage(msgIC)
        // ask all nodes to identify themselves
        let msgVN = Message(mti: MTI.Verify_NodeID_Number_Global, source: node.id)
        linkLayer!.sendMessage(msgVN)

    }

    private func linkDownMessage(_ message : Message, _ node : Node) {
        node.state = Node.State.Uninitialized
    }

    private func verifyNodeIDNumberGlobal(_ message : Message, _ node : Node) {
        if ( message.data.count > 0 && node.id != NodeID(message.data)) {return} // not to us
        let msg = Message(mti: MTI.Verified_NodeID, source: node.id, destination: message.source, data: node.id.toArray())
        linkLayer!.sendMessage(msg)
   }
    
    private func verifyNodeIDNumberAddressed(_ message : Message, _ node : Node) {
        let msg = Message(mti: MTI.Verified_NodeID, source: node.id,  destination: message.source,data: node.id.toArray())
        linkLayer!.sendMessage(msg)
   }
    
    private func protocolSupportInquiry(_ message : Message, _ node : Node) {
        var pips : UInt32 = 0;
        for pip in node.pipSet {
            pips |= pip.rawValue
        }
        let part1 = UInt8( (pips >> 24)&0xFF)
        let part2 = UInt8( (pips >> 16)&0xFF)
        let part3 = UInt8( (pips >>  8)&0xFF)
        let retval : [UInt8] = [part1, part2, part3, 0, 0, 0]  // JMRI wants to see 6 bytes
        
        let msg = Message(mti: MTI.Protocol_Support_Reply, source: node.id, destination: message.source, data: retval)
        linkLayer!.sendMessage(msg)
    }
    
    private func simpleNodeIdentInfoRequest(_ message : Message, _ node : Node) {
        let msg = Message(mti: MTI.Simple_Node_Ident_Info_Reply, source: node.id, destination: message.source, data: node.snip.returnStrings())
        linkLayer!.sendMessage(msg)
    }
    
    private func identifyEventsAddressed(_ message : Message, _ node : Node) {
        // EventProtocol in PIP, but no Events here to reply about; no reply necessary
        // TODO: Hook to eventual Event Processing architecture
    }
    
    ///
    /// Handle a message with an unrecognized MTI by returning OptionalInteractionRejected
    private func unrecognizedMTI(_ message : Message, _ node : Node) {
        // global messages are ignored
        if message.isGlobal() { return }
        // addressed messages get an OptionalInteractionRejected
        logger.notice("received unexpected \(message, privacy: .public), sent OIR")
        let msg = Message(mti: MTI.Optional_Interaction_Rejected, source: node.id, destination: message.source,
                          data: [0x10, 0x43, UInt8((message.mti.rawValue>>8)&0xFF), UInt8(message.mti.rawValue&0xFF)]) // permanent error
        linkLayer!.sendMessage(msg)
   }
    
    private func errorMessageReceived(_ message : Message, _ node : Node) {
        // these are just logged until we have more complex interactions
        logger.notice("received unexpected \(message, privacy: .public)")
    }

    // MARK: -
    
    // is this addressed to this node, or a global message?
    private func checkDestID(_ message : Message, _ node : Node) -> Bool {
        return message.destination == node.id || message.isGlobal()
    }
}
