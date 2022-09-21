//
//  DatagramService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

/// Provide a service interface for reading and writing Datagrams.
/// Writes to remote node:
/// - Create a WriteMemo and submit
/// - Get an OK or NotOK callback
/// Reads from remote node:
///  - Mlutiple listeners are notified
///  - exactly one should call positiveReplyToDatagram/negativeReplyToDatagram before returning from listener
//
// Implements `Processor`, should be fed as part of common execution
//
// TODO: Update the PlantUML diagrams


final public class DatagramService : Processor {
    public init ( _ linkLayer: LinkLayer) {
        self.linkLayer = linkLayer
    }
    private let linkLayer : LinkLayer
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "DatagramService")

    /// Memo carries write request and two reply callbacks
    public struct DatagramWriteMemo : Equatable {
        
        // source is this node
        let destID : NodeID
        let data : [UInt8]
        
        let okReply : ( (_ : DatagramWriteMemo) -> () )?
        let rejectedReply : ( (_ : DatagramWriteMemo) -> () )?
        
        init(destID : NodeID, data : [UInt8], okReply : ( (_ : DatagramWriteMemo) -> () )? = defaultIgnoreReply, rejectedReply : ( (_ : DatagramWriteMemo) -> () )? = defaultIgnoreReply) {
            self.destID = destID
            self.data = data
            self.okReply = okReply
            self.rejectedReply = rejectedReply
        }
        static func defaultIgnoreReply(_ : DatagramWriteMemo) {
            // default handling of reply does nothing
        }
        
        // for Equatable
        public static func == (lhs: DatagramService.DatagramWriteMemo, rhs: DatagramService.DatagramWriteMemo) -> Bool {
            if lhs.destID != rhs.destID { return false }
            if lhs.data != rhs.data { return false }
            return true
        }
    }
    
    /// Memo carries read result
    public struct DatagramReadMemo : Equatable {
        
        let srcID : NodeID
        // destination is this node
        let data : [UInt8]
        
        // for Equatable
        public static func == (lhs: DatagramService.DatagramReadMemo, rhs: DatagramService.DatagramReadMemo) -> Bool {
            if lhs.srcID != rhs.srcID { return false }
            if lhs.data != rhs.data { return false }
            return true
        }
    }
    
    /// Known datagram protocol types
    public enum ProtocolID : UInt8 {
        case LogRequest      = 0x01
        case LogReply        = 0x02
        
        case MemoryOperation = 0x20
        
        case RemoteButton    = 0x21
        case Display         = 0x28
        case TrainControl    = 0x30
        
        case Unrecognized    = 0xFF // Not formally assigned
    }
    
    /// Determine the protocol type of the content of the dataagram.
    /// Returns Unrecognized if there is no type specified, i.e. the datagram is empty
    public func datagramType(data : [UInt8]) -> ProtocolID {
        guard data.count != 0 else { return .Unrecognized }
        if let retval = ProtocolID(rawValue: data[0]) {
            return retval
        } else {
            return .Unrecognized
        }
    }
    
    private var pendingWriteMemos : [DatagramWriteMemo] = []
    
    /// Queue a memo that writes a datagram to the network
    public func sendDatagram(_ memo : DatagramWriteMemo) {
        // Make a record of memo for reply
        pendingWriteMemos.append(memo)
        
        // can only have one outstanding at a time, so check it there was already one there.
        if pendingWriteMemos.count == 1 {
            sendDatagramMessage(memo: memo)
        }
    }
    
    private func sendDatagramMessage(memo : DatagramWriteMemo) {
        // Send datagram message
        let message = Message(mti: MTI.Datagram, source: linkLayer.localNodeID, destination: memo.destID, data: memo.data)
        linkLayer.sendMessage(message)
    }
    
    /// Register a listener to be notified when each datagram arrives.  One and only one listener should reply positively or negatively to the datagram.
    public func registerDatagramReceivedListener(_ listener : @escaping ( (_ : DatagramReadMemo) -> () )) {
        listeners.append(listener)
    }
    private var listeners : [( (_ : DatagramReadMemo) -> () )] = []  // internal for testing
    
    internal func fireListeners(_ dg : DatagramReadMemo) { // internal for testing
        for listener in listeners {
            listener(dg)
        }
        // TODO: If none of the listeners replied by now, send a negative reply
    }
    
    /// Processor entry point.
    /// - Returns: Always false; a datagram doesn't mutate the node, it's the actions brought by that datagram that does.
    public func process( _ message : Message, _ node : Node ) -> Bool {
        // Check that it's to us
        guard checkDestID(message, linkLayer.localNodeID) else { return false }
        
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
        return false
    }
    
    internal func handleDatagram(_ message : Message) {  // internal for testing
        // create a read memo and pass to listeners
        let memo = DatagramReadMemo(srcID: message.source, data: message.data)
        fireListeners(memo) // destination listener calls back to
                            // positiveReplyToDatagram/negativeReplyToDatagram before returning
    }
    
    // OK reply to write
    private func handleDatagramReceivedOK(_ message : Message) {
        // match to the memo and remove from queue
        let memo = matchToWriteMemo(message: message)
        // fire the callback
        memo?.okReply?(memo!)
        
        sendNextDatagramFromQueue()
    }
    
    // Not OK reply to write
    private func handleDatagramRejected(_ message : Message) {
        // match to the memo and remove from queue
        let memo = matchToWriteMemo(message: message)
        // fire the callback
        memo?.rejectedReply?(memo!)

        sendNextDatagramFromQueue()
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
        DatagramService.logger.error("Did not match memo to message \(message)")
        return nil  // this will prevent firther processing
    }
    
    private func sendNextDatagramFromQueue() {
        // is there a next datagram request?
        if pendingWriteMemos.count > 0 {
            // yes, get it, process it
            let memo = pendingWriteMemos[0]
            sendDatagramMessage(memo: memo)
        }
    }
    
    /// Send a positive reply to a received datagram
    public func positiveReplyToDatagram(_ dg : DatagramService.DatagramReadMemo, flags : UInt8 = 0) {
        let message = Message(mti: .Datagram_Received_OK, source: linkLayer.localNodeID, destination: dg.srcID, data: [flags])
        linkLayer.sendMessage(message)
    }
    
    /// Send a negative reply to a received datagram
    public func negativeReplyToDatagram(_ dg : DatagramService.DatagramReadMemo, err : UInt16) {
        let data0 = UInt8((err >> 8 ) & 0xFF)
        let data1 = UInt8(err & 0xFF)
        let message = Message(mti: .Datagram_Rejected, source: linkLayer.localNodeID, destination: dg.srcID, data: [data0, data1])
        linkLayer.sendMessage(message)
    }
}
