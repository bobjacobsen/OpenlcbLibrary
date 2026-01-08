//
//  LocalNodeProcessor.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

/// Process messages destined for the node(s) implemented by this application.
struct LocalNodeProcessor : Processor {
    init ( _ linkLayer: LinkLayer? = nil) {
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer?
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "LocalNodeProcessor")
    
    func process( _ message : Message, _ node : Node ) -> Bool {
        guard checkDestID(message, node) else { return false }  // not to us
        // specific message handling
        switch message.mti {
        case .Link_Layer_Up :
            linkUpMessage(message, node)
        case .Link_Layer_Down :
            linkDownMessage(message, node)
        case .Verify_NodeID_Number_Global :
            verifyNodeIDNumberGlobal(message, node)
        case .Verify_NodeID_Number_Addressed :
            verifyNodeIDNumberAddressed(message, node)
        case .Protocol_Support_Inquiry :
            protocolSupportInquiry(message, node)
        case .Protocol_Support_Reply,
                .Simple_Node_Ident_Info_Reply :
            // this is handled in the RemoteNodeProcessor, ignored here
            break
        case .Traction_Control_Command, .Traction_Control_Reply :
            // this is handled in the ThrottleProcessor, ignored here
            break
        case .Datagram, .Datagram_Rejected, .Datagram_Received_OK :
            // datagrams and datagram replies are handled in the DatagramService
            break
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
        return false;
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
        guard message.data.count == 0 || node.id == NodeID(message.data) else { return } // not to us
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
    }
    
    ///
    /// Handle a message with an unrecognized MTI by returning OptionalInteractionRejected
    private func unrecognizedMTI(_ message : Message, _ node : Node) {
        guard !message.isGlobal() else { return } // global messages are ignored
        
        // addressed messages get an OptionalInteractionRejected
        LocalNodeProcessor.logger.notice("received unexpected \(message, privacy: .public), sent OIR")
        let msg = Message(mti: MTI.Optional_Interaction_Rejected, source: node.id, destination: message.source,
                          data: [0x10, 0x43, UInt8((message.mti.rawValue>>8)&0xFF), UInt8(message.mti.rawValue&0xFF)]) // permanent error
        linkLayer!.sendMessage(msg)
   }
    
    private func errorMessageReceived(_ message : Message, _ node : Node) {
        // these are just logged until we have more complex interactions
        LocalNodeProcessor.logger.notice("received unexpected \(message, privacy: .public)")
        if message.mti == .Optional_Interaction_Rejected {
            // if this is flagged as a response to PIP or SNIP and temporary error, repeat
            var data2: UInt8 = 0xFF
            if message.data.count >= 3 {
                data2 = message.data[2]
            }
            var data3: UInt8 = 0xFF
            if message.data.count >= 4 {
                data3 = message.data[3]
            }
            let replyTo = Int(data2)*256 + Int(data3)
            if replyTo == MTI.Protocol_Support_Inquiry.rawValue || replyTo == MTI.Simple_Node_Ident_Info_Request.rawValue {
                let errorCode : Int = Int(message.data[0])*256 + Int(message.data[1])
                if errorCode & 0xFFF0 == 0x1000 {
                    let mti = MTI(rawValue: replyTo)
                    let msg = Message(mti: mti!, source: node.id, destination: message.source,
                                      data: [])
                    linkLayer!.sendMessage(msg)
                }
            }
        }
    }

    // MARK: -
    
    // is this addressed to this node, or a global message?
    private func checkDestID(_ message : Message, _ node : Node) -> Bool {
        return message.destination == node.id || message.isGlobal()
    }
}
