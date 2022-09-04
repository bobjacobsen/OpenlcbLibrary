//
//  DatagramService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Provide a service interface for reading and writing Datagrams.
//
// Implements `Processor`, should be fed as part of common execution
//
// TODO: Update the PlantUML diagrams
//
class DatagramService : Processor {
    public init ( _ linkLayer: LinkLayer? = nil) {
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer?
    
    // Memo carries write request and two reply callbacks
    struct DatagramWriteMemo : Equatable {
        
        let srcID : NodeID
        let destID : NodeID
        let data : [UInt8]

        let okReply : ( (_ : Message) -> () )? = defaultIgnoreReply
        let rejectedReply : ( (_ : Message) -> () )? = defaultIgnoreReply
        
        static func defaultIgnoreReply(_ : Message) {
            // default handling of reply does nothing
        }

        // for Equatable
        static func == (lhs: DatagramService.DatagramWriteMemo, rhs: DatagramService.DatagramWriteMemo) -> Bool {
            if lhs.srcID != rhs.srcID { return false }
            if lhs.destID != rhs.destID { return false }
            if lhs.data != rhs.data { return false }
            return true
        }
    }

    // Memo carries read result
    struct DatagramReadMemo : Equatable {
        
        let srcID : NodeID
        let destID : NodeID
        let data : [UInt8]
                
        // for Equatable
        static func == (lhs: DatagramService.DatagramReadMemo, rhs: DatagramService.DatagramReadMemo) -> Bool {
            if lhs.srcID != rhs.srcID { return false }
            if lhs.destID != rhs.destID { return false }
            if lhs.data != rhs.data { return false }
            return true
        }
    }

    enum DatagramProtocolID : UInt {
        case LogRequest      = 0x01
        case LogReply        = 0x02
        
        case MemoryOperation = 0x20
        
        case RemoteButton    = 0x21
        case Display         = 0x28
        case TrainControl    = 0x30
        
        case Unrecognized    = 0xFFF // 12 bits: out of possible normal range
    }

    /// Returns Unrecognized if there is no type specified, i.e. the datagram is empty
    func datagramType(data : [UInt8]) -> DatagramProtocolID {
        if (data.count == 0) { return .Unrecognized }
        if let retval = DatagramProtocolID(rawValue: UInt(data[0])) {
            return retval
        } else {
            return .Unrecognized
        }
    }

    func sendDatagram(_ memo : DatagramWriteMemo) {
        //let message = Message(mti: MTI.Datagram, source: memo.srcNode.id, destination: memo.destNode.id, data: memo.data)
        
        // TODO: Make a record of memo for reply
        
        // TODO: Send datagram message
    }
    
    func registerDatagramReceivedListener(_ listener : @escaping ( (_ : DatagramReadMemo) -> () )) {
        listeners.append(listener)
    }
    var listeners : [( (_ : DatagramReadMemo) -> () )] = []
    
    func fireListeners(_ dg : DatagramReadMemo) {
        for listener in listeners {
            listener(dg)
        }
    }

    public func process( _ message : Message, _ node : Node ) {
        switch message.mti {
        case MTI.Datagram :
            handleDatagram(message)
        case MTI.Datagram_Rejected :
            handleDatagramRejected(message)
        case MTI.Datagram_Received_OK :
            handleDatagramReceivedOK(message)
        default:
            // no need to do anything
            break
        }
    }
    
    func handleDatagram(_ message : Message) {
        // TODO: handle Datagram
    }
    
    func handleDatagramReceivedOK(_ message : Message) {
        // TODO: handle DatagramReceivedOK
    }
    
    func handleDatagramRejected(_ message : Message) {
        // TODO: handle DatagramRejected
    }

}
