//
//  LocalNodeProcessor.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

struct LocalNodeProcessor : Processor {
    public init ( _ linkLayer: LinkLayer? = nil) {
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer?

    func process( _ message : Message, _ node : Node ) {
        if ( !checkDestID(message, node) ) { return }  // not to us
        // specific message handling
        switch message.mti {
        case .LinkLevelUp :
            linkUpMessage(message, node)
        case .LinkLevelDown :
            linkDownMessage(message, node)
        case .VerifyNodeIDNumberGlobal :
            verifyNodeIDNumberGlobal(message, node)
        case .VerifyNodeIDNumberAddressed :
            verifyNodeIDNumberAddressed(message, node)
        case .ProtocolSupportInquiry :
            protocolSupportInquiry(message, node)
        case .SimpleNodeIdentInfoRequest :
            simpleNodeIdentInfoRequest(message, node)
        case .IdentifyEventsAddressed :
            identifyEventsAddressed(message, node)
        default:
            break
        }
        // datagrams and datagram replies are handled in the DatagramProcessor/DatagramService
    }

    private func linkUpMessage(_ message : Message, _ node : Node) {
        node.state = Node.State.Initialized
        let msg = Message(mti: MTI.InitializationComplete, source: node.id, data: node.id.toArray())
        linkLayer!.sendMessage(msg)
    }

    private func linkDownMessage(_ message : Message, _ node : Node) {
        node.state = Node.State.Uninitialized
    }

    private func verifyNodeIDNumberGlobal(_ message : Message, _ node : Node) {
        if ( message.data.count > 0 && node.id != NodeID(message.data)) {return} // not to us
        let msg = Message(mti: MTI.VerifiedNodeID, source: node.id, destination: message.source, data: node.id.toArray())
        linkLayer!.sendMessage(msg)
   }
    
    private func verifyNodeIDNumberAddressed(_ message : Message, _ node : Node) {
        let msg = Message(mti: MTI.VerifiedNodeID, source: node.id,  destination: message.source,data: node.id.toArray())
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
        
        let msg = Message(mti: MTI.ProtocolSupportReply, source: node.id, destination: message.source, data: retval)
        linkLayer!.sendMessage(msg)
    }
    
    private func simpleNodeIdentInfoRequest(_ message : Message, _ node : Node) {
        let msg = Message(mti: MTI.SimpleNodeIdentInfoReply, source: node.id, destination: message.source, data: node.snip.returnStrings())
        linkLayer!.sendMessage(msg)
    }
    
    private func identifyEventsAddressed(_ message : Message, _ node : Node) {
        // EventProtocol not in PIP, so decode and reject those messages
        let msg = Message(mti: MTI.OptionalInteractionRejected, source: node.id, destination: message.source,
                          data: [0x10, 0x43, UInt8((message.mti.rawValue>>8)&0xFF), UInt8(message.mti.rawValue&0xFF)]) // permanent error
        linkLayer!.sendMessage(msg)
    }
    
    // MARK: -
    
    // is this addressed to this node, or a global message?
    private func checkDestID(_ message : Message, _ node : Node) -> Bool {
        return message.destination == node.id || message.isGlobal()
    }
}
