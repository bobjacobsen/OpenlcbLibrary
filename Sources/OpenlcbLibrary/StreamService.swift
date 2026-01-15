//
//  StreamService.swift
//  OpenlcbLibrary
//
//  Created by Bob Jacobsen on 1/8/26.
//

import Foundation
import os

/// Provide a service interface for reading and writing Datagrams.
///
/// To write data through a stream, call ``createWriteStream()``  with the data to send.  This replies with one of three callbacks:
///  - pprogressCallBack - called with each stream buffer send, provides the total number of bytes to transfer and the number so far sent
///  - okReply - the operation completed successfully
///  - rejectedReply - operation failed, contains the error code if any

final public class StreamService : Processor  {
    
    public init ( _ linkLayer: LinkLayer) {
        self.linkLayer = linkLayer
    }
    private let linkLayer : LinkLayer
    
    private var pendingOperations: [StreamWriteMemo] = []
    private var quiesced = false
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "StreamService")

    static var nextProposedDestStreamNumber : UInt8 = 0
    
    final public class StreamWriteMemo : Equatable, CustomStringConvertible, Hashable {
        let destNodeId : NodeID
        let sourceStreamNumber : UInt8
        var destStreamNumber : UInt8
        var bufferSize : Int

        let wholeData : [UInt8]
        var nextWrite : Int = 0
        
        let okReply : ( (_ : StreamWriteMemo) -> () )?
        let rejectedReply : ( (_ : StreamWriteMemo, _ : Int) -> () )?
        var progressCallBack: ( (_ : StreamWriteMemo, _ : Int, _ : Int, _ : Bool) -> () )?

        init(nodeId: NodeID, sourceStreamNumber: UInt8, bufferSize: Int, wholeData : [UInt8],
                okReply : ( (_ : StreamWriteMemo) -> () )? = nil,
                rejectedReply : ( (_ : StreamWriteMemo, _ : Int) -> () )? = nil,
                progressCallBack: ( (_ : StreamWriteMemo, _ : Int, _ : Int, _ : Bool) -> () )? = nil
            ) {
            self.sourceStreamNumber = sourceStreamNumber
            self.destStreamNumber = nextProposedDestStreamNumber
            nextProposedDestStreamNumber += 1
            self.destNodeId = nodeId
            self.bufferSize = bufferSize
            self.wholeData = wholeData
            self.okReply = okReply
            self.rejectedReply = rejectedReply
            self.progressCallBack = progressCallBack
        }
        // for CustomStringConvertible
        public var description: String {
            return "StreamWriteMemo: node \(destNodeId) source stream \(sourceStreamNumber), dest stream \(destStreamNumber)"
        }
        // for Equatable
        public static func == (lhs: StreamService.StreamWriteMemo, rhs: StreamService.StreamWriteMemo) -> Bool {
            if lhs.sourceStreamNumber != rhs.sourceStreamNumber { return false }
            // dest stream number can vary as it comes back from remote node
            if lhs.destNodeId != rhs.destNodeId { return false }
            return true
        }
        // for Hashable
        public func hash(into hasher : inout Hasher) {
            hasher.combine(sourceStreamNumber)
            hasher.combine(destNodeId)
        }
    }
    
    public func createWriteStream(withMemo : StreamWriteMemo) {
    
        pendingOperations.append(withMemo)
        
        let buffer1 = (UInt8)((withMemo.bufferSize >> 8)&0xFF)
        let buffer2 = (UInt8)((withMemo.bufferSize)&0xFF)

        // create the stream by sending a Stream Init Request message
        let msg = Message(mti: .Stream_Initiate_Request, source: linkLayer.localNodeID, destination: withMemo.destNodeId,
                          data: [buffer1, buffer2, 0,0, 0x04, 0x00])  // request with 0 flags, dest stream is zero TODO: This has a fixed source stream ID
        linkLayer.sendMessage(msg)
    }
        
    private func startSendStreamData(withMemo: StreamWriteMemo) {
    
        var content : [UInt8] = Array(withMemo.wholeData[0..<min(withMemo.bufferSize, withMemo.wholeData.count)])
        content.insert((UInt8)(withMemo.destStreamNumber), at: 0)

        withMemo.nextWrite += content.count-1 // there's one header byte for the destStreamNumber
        
        let msg = Message(mti: .Stream_Data_Send, source: linkLayer.localNodeID,
                          destination: withMemo.destNodeId,
                          data: content)
        linkLayer.sendMessage(msg)
        
        // is this the only stream buffer to send?  if so, send end
        if withMemo.nextWrite >= withMemo.wholeData.count {
            // no more data, send stream done message
            let msg = Message(mti: .Stream_Data_Complete, source: linkLayer.localNodeID,
                              destination: withMemo.destNodeId,
                              data: [(UInt8)(withMemo.sourceStreamNumber), (UInt8)(withMemo.destStreamNumber)])
            linkLayer.sendMessage(msg)
            if let progressCallback = withMemo.progressCallBack {
                progressCallback(withMemo, withMemo.wholeData.count, withMemo.nextWrite, true)  // because [0] is first, nextWrite is count of sent
            }
            if let goodCallBack = withMemo.okReply {
                goodCallBack(withMemo)
            }
            return
        } else {
            // progress but not end
            if let callback = withMemo.progressCallBack {
                callback(withMemo, withMemo.wholeData.count, withMemo.nextWrite, false)  // because [0] is first, nextWrite is count of sent
            }
        }

    }
    
    /// Message Processor entry point.
    /// - Returns: Always false; a stream operation doesn't mutate the node, it's the actions brought by that datagram that does.
    public func process(_ message: Message, _ node: Node) -> Bool {
        // Check that it's to us or a global (for link layer up)
        guard message.isGlobal() || checkDestID(message, linkLayer.localNodeID) else { return false }
        
        switch message.mti {
        case .Stream_Initiate_Reply:
            handleStreamInitiateReply(message)
        case .Stream_Data_Proceed:
            handleStreamDataProceed(message)
        case .Link_Layer_Quiesce :
            handleLinkQuiesce(message)
        case .Link_Layer_Restarted :
            handleLinkRestarted(message)
        case .Initialization_Complete :
            handleInitializationComplete(message)
        default:
            // no need to do anything
            break
        }
        return false
    }

    private func findPendingMemo(from : Message) -> StreamWriteMemo? {
        for memo in pendingOperations {
            if memo.destNodeId == from.source {
                return memo
            }
        }
        return nil
    }
        
    private func handleStreamInitiateReply(_ message : Message) {
        guard message.data.count >= 6 else {
            StreamService.logger.warning("Stream Init Reply too short: \(message.data)")
            return
        }
        // match to a request
        guard let pendingMemo = findPendingMemo(from: message) else {
            StreamService.logger.warning("Stream Init Reply does not match any request: \(message)")
            return
        }
        let code : Int = ((Int)(message.data[2])<<8) + (Int)(message.data[3])
        pendingMemo.bufferSize = (Int)(message.data[0])<<8+(Int)(message.data[1])
        pendingMemo.destStreamNumber = message.data[5]
        guard pendingMemo.sourceStreamNumber == message.data[4] else {
            // here unexpected reply with source stream number changed
            StreamService.logger.warning("Stream Init Reply changed source number from \(pendingMemo.sourceStreamNumber) to \(message.data[4])")
            // invoke the bad reply
            if let rejectedReply = pendingMemo.rejectedReply {
                rejectedReply(pendingMemo, code)
            }
            return
        }
       guard code&0x7FFF == 0 else {
            // here negative reply with non-zero error code
            StreamService.logger.warning("Stream Init Reply rejected with code \(code)")
            // invoke the bad reply
            if let rejectedReply = pendingMemo.rejectedReply {
                rejectedReply(pendingMemo, code)
            }
            return
        }
        // here positive reply, no error code in lower bits, so start transfer
        StreamService.logger.debug("Stream Init Reply ok with code \(code)")
        // invoke the good reply
        startSendStreamData(withMemo: pendingMemo)
        return
    }

    private func handleStreamDataProceed(_ message : Message) {
        guard message.data.count >= 2 else {
            StreamService.logger.warning("Stream Init Reply too short: \(message.data)")
            return
        }
        // match to a request
        guard let pendingMemo = findPendingMemo(from: message) else {
            StreamService.logger.warning("Stream Init Reply does not match any request: \(message)")
            return
        }
        // by definition, a positive reply, check for no data left
        if pendingMemo.nextWrite >= pendingMemo.wholeData.count {
            // no more data, send stream done message
            let msg = Message(mti: .Stream_Data_Complete, source: linkLayer.localNodeID,
                              destination: pendingMemo.destNodeId,
                              data: [(UInt8)(pendingMemo.sourceStreamNumber), (UInt8)(pendingMemo.destStreamNumber)])
            linkLayer.sendMessage(msg)
            if let callback = pendingMemo.progressCallBack {
                callback(pendingMemo, pendingMemo.wholeData.count, pendingMemo.nextWrite-1, true) // because [0] is first, nextWrite is count of sent
            }
            if let goodCallBack = pendingMemo.okReply {
                goodCallBack(pendingMemo)
            }
            return
        }
        
        // fire progress call back and send next buffer of data
        let lowerLimit = pendingMemo.nextWrite
        let upperLimit = min(pendingMemo.wholeData.count, pendingMemo.nextWrite + pendingMemo.bufferSize)
        
        var content : [UInt8] = Array(pendingMemo.wholeData[lowerLimit..<upperLimit])
        content.insert((UInt8)(pendingMemo.destStreamNumber), at:   0)
        pendingMemo.nextWrite += content.count - 1 // -1 due to stream at front
        let msg = Message(mti: .Stream_Data_Send, source: linkLayer.localNodeID,
                          destination: pendingMemo.destNodeId,
                          data: content)
        linkLayer.sendMessage(msg)
        
        // check for no more data left
        if pendingMemo.nextWrite >= pendingMemo.wholeData.count {
            // no more data, send stream done message
            let msg = Message(mti: .Stream_Data_Complete, source: linkLayer.localNodeID,
                              destination: pendingMemo.destNodeId,
                              data: [(UInt8)(pendingMemo.sourceStreamNumber), (UInt8)(pendingMemo.destStreamNumber)])
            linkLayer.sendMessage(msg)
            if let callback = pendingMemo.progressCallBack {
                callback(pendingMemo, pendingMemo.wholeData.count, pendingMemo.nextWrite, true) // because [0] is first, nextWrite is count of sent
            }
            if let goodCallBack = pendingMemo.okReply{
                goodCallBack(pendingMemo)
            }
            return
        } else {
            // not done yet
            if let callback = pendingMemo.progressCallBack {
                callback(pendingMemo, pendingMemo.wholeData.count, pendingMemo.nextWrite, false) // because [0] is first, nextWrite is count of sent
            }
        }
    }

    // Link quiesced before outage: stop operation
    private func handleLinkQuiesce(_ message : Message) {
        quiesced = true
    }
    
    // Link restarted after outage: if write datagram(s) pending reply
    // from during quieced time, resend them
    private func handleLinkRestarted(_ message : Message) {
        quiesced = false
    }
    
    // if our outstanding datagram destination initialized, e.g. as part of FirmwareUpdate,
    // mark that datagram as rejected
    private func handleInitializationComplete(_ message : Message) {
    }
}
