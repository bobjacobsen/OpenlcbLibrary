//
//  DatagramService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

/// Provide a service interface for reading and writing Datagrams.
//
// Implements `Processor`, should be fed as part of common execution
//
// TODO: Update the PlantUML diagrams
//
public class DatagramService : Processor {
    public init ( _ linkLayer: LinkLayer) {
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "DatagramService")

    // Memo carries write request and two reply callbacks
    struct DatagramWriteMemo : Equatable {
        
        // source is this node
        let destID : NodeID
        let data : [UInt8]
        
        let okReply : ( (_ : Message) -> () )?
        let rejectedReply : ( (_ : Message) -> () )?
        
        init(destID : NodeID, data : [UInt8], okReply : ( (_ : Message) -> () )? = defaultIgnoreReply, rejectedReply : ( (_ : Message) -> () )? = defaultIgnoreReply) {
            self.destID = destID
            self.data = data
            self.okReply = okReply
            self.rejectedReply = rejectedReply
        }
        static func defaultIgnoreReply(_ : Message) {
            // default handling of reply does nothing
        }
        
        // for Equatable
        static func == (lhs: DatagramService.DatagramWriteMemo, rhs: DatagramService.DatagramWriteMemo) -> Bool {
            if lhs.destID != rhs.destID { return false }
            if lhs.data != rhs.data { return false }
            return true
        }
    }
    
    // Memo carries read result
    struct DatagramReadMemo : Equatable {
        
        let srcID : NodeID
        // destination is this node
        let data : [UInt8]
        
        // for Equatable
        static func == (lhs: DatagramService.DatagramReadMemo, rhs: DatagramService.DatagramReadMemo) -> Bool {
            if lhs.srcID != rhs.srcID { return false }
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
    
    private var pendingWriteMemos : [DatagramWriteMemo] = []
    
    func sendDatagram(_ memo : DatagramWriteMemo) {
        // Make a record of memo for reply
        pendingWriteMemos.append(memo)

        // Send datagram message
        let message = Message(mti: MTI.Datagram, source: linkLayer.localNodeID, destination: memo.destID, data: memo.data)
        linkLayer.sendMessage(message)
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
        // Check that it's to us
        if !checkDestID(message, linkLayer.localNodeID) { return }
        
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
        // create a read memo and pass to listeners
        let memo = DatagramReadMemo(srcID: message.source, data: message.data)
        fireListeners(memo)
    }
    
    func handleDatagramReceivedOK(_ message : Message) {
        // match to the memo
        let memo = matchToWriteMemo(message: message)
        // fire the callback
        memo?.okReply?(message)
    }
    
    func handleDatagramRejected(_ message : Message) {
        // match to the memo
        let memo = matchToWriteMemo(message: message)
        // fire the callback
        memo?.rejectedReply?(message)
    }
    
    private func matchToWriteMemo(message : Message) -> DatagramService.DatagramWriteMemo? {
        for memo in pendingWriteMemos {
            if memo.destID != message.source { break }
            // remove the found element
            if let index = pendingWriteMemos.firstIndex(of: memo) {
                pendingWriteMemos.remove(at: index)
            }
            return memo
        }
        // did not find one
        logger.error("Did not match memo to message \(message)")
        return nil  // this will prevent firther processing
    }
    
    func positiveReplyToDatagram(_ dg : DatagramService.DatagramReadMemo, flags : UInt8 = 0) {
        let message = Message(mti: .Datagram_Received_OK, source: linkLayer.localNodeID, destination: dg.srcID, data: [flags])
        linkLayer.sendMessage(message)
    }
    
    func negativeReplyToDatagram(_ dg : DatagramService.DatagramReadMemo, err : UInt16) {
        let data0 = UInt8((err >> 8 ) & 0xFF)
        let data1 = UInt8(err & 0xFF)
        let message = Message(mti: .Datagram_Rejected, source: linkLayer.localNodeID, destination: dg.srcID, data: [data0, data1])
        linkLayer.sendMessage(message)
    }
}
