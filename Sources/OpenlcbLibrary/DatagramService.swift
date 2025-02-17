//
//  DatagramService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os


/// Provide a service interface for reading and writing Datagrams.
/// 
/// Writes to remote node:
/// - Create a ``DatagramWriteMemo`` and submit via ``sendDatagram(_:)``
/// - Get an OK or NotOK callback
///
/// Reads from remote node:
///  - One or more listeners register via ``registerDatagramReceivedListener(_:)``
///  - Listeners are notified via call back
///  - Exactly one should call ``positiveReplyToDatagram(_:flags:)`` or ``negativeReplyToDatagram(_:err:)`` before returning from listener
///
/// Implements `Processor`, should be fed as part of common execution
///
/// Handles link quiesce/restart so that higher level services don't have to.
///    1) If there's an outstanding datagram reply with link restarts, resend it
///    2) Once the link has been quiesced, datagrams are held until it's restarted
///    
final public class DatagramService : Processor {
    public init ( _ linkLayer: LinkLayer) {
        self.linkLayer = linkLayer
    }
    private let linkLayer : LinkLayer
    private var quiesced = false
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "DatagramService")

    private var currentOutstandingMemo : DatagramWriteMemo? = nil
    
    /// Immutable memo carrying write request and two reply callbacks.
    ///
    /// Source is automatically this node.
    public struct DatagramWriteMemo : Equatable, CustomStringConvertible {
        
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
            
        // for CustomStringConvertible
        public var description: String {
            return "DatagramWriteMemo: to \(destID) contains: \(data)"
        }

        // for Equatable
        public static func == (lhs: DatagramService.DatagramWriteMemo, rhs: DatagramService.DatagramWriteMemo) -> Bool {
            if lhs.destID != rhs.destID { return false }
            if lhs.data != rhs.data { return false }
            return true
        }
    }
    
    /// Immutable memo carrying read result.
    ///
    /// Destination of operations is automatically this node.
    public struct DatagramReadMemo : Equatable {
        
        let srcID : NodeID
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
    
    /// Determine the protocol type of the content of the datagram.
    ///
    ///  - Returns: 'Unrecognized' if there is no type specified, i.e. the datagram is empty
    public func datagramType(data : [UInt8]) -> ProtocolID {
        guard data.count != 0 else { return .Unrecognized }
        if let retval = ProtocolID(rawValue: data[0]) {
            return retval
        } else {
            return .Unrecognized
        }
    }
    
    private var pendingWriteMemos : [DatagramWriteMemo] = []
    
    /// Queue a ``DatagramWriteMemo`` to send a datagram to another node on the network.
    public func sendDatagram(_ memo : DatagramWriteMemo) {
        // Make a record of memo for reply
        pendingWriteMemos.append(memo)
        
        // can only have one outstanding at a time, so check it there was already one there.
        if pendingWriteMemos.count == 1 {
            sendDatagramMessage(memo: memo)
        }
    }
    
    private func sendNextDatagramFromQueue() {
        // is there a next datagram request?
        if pendingWriteMemos.count > 0 {
            // yes, get it, process it
            let memo = pendingWriteMemos[0]
            sendDatagramMessage(memo: memo)
        }
    }
    
    private func sendDatagramMessage(memo : DatagramWriteMemo) {
        // Send datagram message
        let message = Message(mti: MTI.Datagram, source: linkLayer.localNodeID, destination: memo.destID, data: memo.data)
        linkLayer.sendMessage(message)
        currentOutstandingMemo = memo
        // and start timer
        startTimer(memo)
    }
    
    /// Register a listener to be notified when each datagram arrives.
    ///
    /// One and only one listener should reply positively or negatively to the datagram and return true.
    public func registerDatagramReceivedListener(_ listener : @escaping ( (_ : DatagramReadMemo) -> Bool )) {
        listeners.append(listener)
    }
    private var listeners : [( (_ : DatagramReadMemo) -> Bool )] = []  // internal for testing
    
    internal func fireListeners(_ dg : DatagramReadMemo) { // internal for testing
        var replied = false
        for listener in listeners {
            replied = listener(dg) || replied    // order matters on that: Need to always make the call
        }
        // If none of the listeners replied by now, send a negative reply
        if !replied {
            negativeReplyToDatagram(dg, err: 0x1042)  // “Not implemented, datagram type unknown” - permanent error
        }
    }
    
    
    
    /// Message Processor entry point.
    /// - Returns: Always false; a datagram doesn't mutate the node, it's the actions brought by that datagram that does.
    public func process( _ message : Message, _ node : Node ) -> Bool {
        // Check that it's to us or a global (for link layer up)
        guard message.isGlobal() || checkDestID(message, linkLayer.localNodeID) else { return false }
        
        switch message.mti {
        case .Datagram :
            handleDatagram(message)
        case .Datagram_Rejected :
            handleDatagramRejected(message)
        case .Datagram_Received_OK :
            handleDatagramReceivedOK(message)
        case .Link_Layer_Quiesce :
            handleLinkQuiesce(message)
        case .Link_Layer_Restarted :
            handleLinkRestarted(message)
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
        
        clearTimer()
        
        // match to the memo and remove from queue
        let memo = removeMatchingWriteMemo(message: message)
        
        // check of tracking logic
        if currentOutstandingMemo != memo {
            DatagramService.logger.error("Outstanding and replied-to memos don't match on OK reply")
        }
        currentOutstandingMemo = nil
        
        // fire the callback if it exists
        if let thisMemo = memo {
            if let replyMethod = thisMemo.okReply {
                replyMethod(thisMemo)
            }
        }

        sendNextDatagramFromQueue()
    }
    
    // Not OK reply to write
    private func handleDatagramRejected(_ message : Message) {
        
        clearTimer()

        // match to the memo and remove from queue
        let memo = removeMatchingWriteMemo(message: message)
        handleDatagramFail(failedMemo: memo)
    }
        
    private func handleDatagramFail(failedMemo memo : DatagramWriteMemo?) {
        
        if let thisMemo = memo {
            if let index = pendingWriteMemos.firstIndex(of: thisMemo) {
                pendingWriteMemos.remove(at: index)
            }
        }
        
        // check of tracking logic
        if currentOutstandingMemo != memo {
            DatagramService.logger.error("Outstanding and replied-to memos don't match on rejected")
        }
        currentOutstandingMemo = nil

        // fire the callback if it exists - this may immediately call sendMessage, or not
        if let thisMemo = memo {
            _ = removeMatchingWriteMemo(thisMemo)
            if let replyMethod = thisMemo.rejectedReply {
                replyMethod(thisMemo)
            }
        }
        
        sendNextDatagramFromQueue()
    }
   
    // Link quiesced before outage: stop operation
    private func handleLinkQuiesce(_ message : Message) {
        quiesced = true
        clearTimer()  // will restart when link restarted
    }

    // Link restarted after outage: if write datagram(s) pending reply, resend them
    private func handleLinkRestarted(_ message : Message) {
        quiesced = false
        clearTimer()  // just in case
        if currentOutstandingMemo != nil {
            // there's a current outstanding memo to repeat
            DatagramService.logger.info("Retrying datagram after restart")
            sendDatagramMessage(memo: currentOutstandingMemo!)
            return
        } else {
            // are there any queued datagrams? If so, send first
            if pendingWriteMemos.count > 0 {
                sendNextDatagramFromQueue()
            }
        }
    }
    
    private var timer : Timer?
    private let TIMEOUT_INTERVAL = 3.0  // seconds
    private var retryCount = 0;
    private let MAX_TIMEOUT_RETRIES = 2

    
    private func startTimer(_ memo : DatagramWriteMemo) {
        if let _ = timer {
            // there's already a timer running, but there
            // shouldn't be because this service is one-at-a-time.
            DatagramService.logger.error("Timer already running in startTimer, will invalidate")
            clearTimer()
        }
        timer = Timer.scheduledTimer(withTimeInterval: TIMEOUT_INTERVAL, repeats: false) {timer in
                    self.timerFired(memo)
                }
    }
    
    // invoked when a reply is received in time
    private func clearTimer() {
        if let thisTimer = timer {
            thisTimer.invalidate()
            timer = nil;
            retryCount = 0;
        }
    }
    
    // invoked when no reply received in time
    private func timerFired(_ memo : DatagramWriteMemo) {
        // invalidate timer, just in case
        if let thisTimer = timer {
            thisTimer.invalidate()
            timer = nil;
        }

        // decide what to do about this timeout
        if retryCount <= MAX_TIMEOUT_RETRIES {
            retryCount = retryCount + 1
            // Retry the transmission, without notifying higher levels
            sendDatagramMessage(memo: memo)
        } else {
            // Too many retries, this is a negative reply
            retryCount = 0
            handleDatagramFail(failedMemo: memo)
        }
        
    }
    
    private func removeMatchingWriteMemo(message : Message) -> DatagramService.DatagramWriteMemo? {
        for thisMemo in pendingWriteMemos {
            if thisMemo.destID != message.source { break }
            // remove the found element
            if let index = pendingWriteMemos.firstIndex(of: thisMemo) {
                pendingWriteMemos.remove(at: index)
            }
            return thisMemo
        }
        // did not find one
        DatagramService.logger.error("Did not match memo to message \(message)")
        return nil  // this will prevent firther processing
    }
    
    private func removeMatchingWriteMemo(_ inputMemo : DatagramWriteMemo) -> DatagramService.DatagramWriteMemo? {
        for thisMemo in pendingWriteMemos {
            if thisMemo.destID != inputMemo.destID { break }
            // remove the found element
            if let index = pendingWriteMemos.firstIndex(of: thisMemo) {
                pendingWriteMemos.remove(at: index)
            }
            return thisMemo
        }
        // did not find one
        DatagramService.logger.error("Did not match memo to existing list")
        return nil  // this will prevent firther processing
    }
    


    /// Send a positive reply to a received datagram. Called from datagram receiver.
    /// - Parameters:
    ///   - dg: Datagram memo being responded to.
    ///   - flags: Flag byte to be returned to sender, see Datagram S&TN for meaning.
    public func positiveReplyToDatagram(_ dg : DatagramService.DatagramReadMemo, flags : UInt8 = 0) {
        let message = Message(mti: .Datagram_Received_OK, source: linkLayer.localNodeID, destination: dg.srcID, data: [flags])
        linkLayer.sendMessage(message)
    }
    
    /// Send a negative reply to a received datagram. Called from datagram receiver.
    /// - Parameters:
    ///   - dg: Datagram memo being responded to.
    ///   - err: Error code(s) to be returned to sender, see Datagram S&TN for meaning.
    public func negativeReplyToDatagram(_ dg : DatagramService.DatagramReadMemo, err : UInt16) {
        let data0 = UInt8((err >> 8 ) & 0xFF)
        let data1 = UInt8(err & 0xFF)
        let message = Message(mti: .Datagram_Rejected, source: linkLayer.localNodeID, destination: dg.srcID, data: [data0, data1])
        linkLayer.sendMessage(message)
    }
}
