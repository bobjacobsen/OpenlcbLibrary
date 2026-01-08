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
/// To set up a write stream;
///     - Call ``createWriteStream()`` which calls back with a ``StreamWriteMemo``
///     - Use that memo to call ``writeDataToStream`` one or more times
///     - Use that memo to call ``closeDataStream``

final public class StreamService : Processor  {
    
    public init ( _ linkLayer: LinkLayer) {
        self.linkLayer = linkLayer
    }
    private let linkLayer : LinkLayer
    
    private var pendingOperations: [StreamWritePendingDataMemo] = []
    private var quiesced = false
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "DatagramService")

    final public class StreamWriteUserMemo : Equatable, CustomStringConvertible {
        let sourceStreamNumber : Int
        let destStreamNumber : Int
        let nodeId : NodeID
        let bufferSize : Int

        init(sourceStreamNumber: Int, destStreamNumber: Int, nodeId: NodeID, bufferSize: Int) {
            self.sourceStreamNumber = sourceStreamNumber
            self.destStreamNumber = destStreamNumber
            self.nodeId = nodeId
            self.bufferSize = bufferSize
        }
        // for CustomStringConvertible
        public var description: String {
            return "StreamWriteMemo: node \(nodeId) source stream \(sourceStreamNumber), dest stream \(destStreamNumber)"
        }
        // for Equatable
        public static func == (lhs: StreamService.StreamWriteUserMemo, rhs: StreamService.StreamWriteUserMemo) -> Bool {
            if lhs.sourceStreamNumber != rhs.sourceStreamNumber { return false }
            if lhs.destStreamNumber != rhs.destStreamNumber { return false }
            if lhs.nodeId != rhs.nodeId { return false }
            return true
        }
    }
    
    final class StreamWritePendingDataMemo {
        let memo : StreamWriteUserMemo? = nil
        let destNodeID : NodeID

        var sourceStreamNumber : Int = 0xFF
        var destStreamNumber : Int = 0xFF

        var wholeData : [UInt8] = []
        var nextWrite : Int = 0
        var bufferSize : Int = 0
        
        let okReply : ( (_ : StreamWriteUserMemo) -> () )
        let rejectedReply : ( (_ : StreamWriteUserMemo, _ : Int) -> () )
        
        init(destNodeID: NodeID, sourceStreamNumber: Int,
                okReply: @escaping (_: StreamWriteUserMemo) -> Void, rejectedReply: @escaping (_: StreamWriteUserMemo, _: Int) -> Void) {
            self.destNodeID = destNodeID
            self.sourceStreamNumber = sourceStreamNumber
            self.okReply = okReply
            self.rejectedReply = rejectedReply
        }
    }
    
    let nextStreamNumber = 0
    
    public func createWriteStream(toNode: NodeID, okReply : @escaping ( (_ : StreamWriteUserMemo) -> () ),
                                  rejectedReply : @escaping ( (_ : StreamWriteUserMemo, _ : Int) -> () )) {
    
        // create a PendingMemo to remember the call backs
        let pendingMemo = StreamWritePendingDataMemo(
                                    destNodeID: toNode, sourceStreamNumber: nextStreamNumber,
                                    okReply: okReply, rejectedReply: rejectedReply
                                )
        pendingOperations.append(pendingMemo)
        
        // create the stream by sending a Stream Init Request message
        let msg = Message(mti: .Stream_Initiate_Request, source: linkLayer.localNodeID, destination: toNode,
                          data: [0, 0, 0x01, 0x00 , 0x00, 0x00])  // request 256 bytes (32 frames) at a time
        linkLayer.sendMessage(msg)
    }
    
    public func sendStreamData(with: StreamWriteUserMemo, contains: [UInt8]) {
    
        var content : [UInt8] = Array(contains[0..<min(with.bufferSize-2, contains.count)])
        content.insert((UInt8)(with.destStreamNumber), at: 0)
        content.insert((UInt8)(with.sourceStreamNumber), at: 1)

        guard let pendingMemo = findPendingMemo(from: with) else {
            StreamService.logger.warning("sendStreamData does not match any pending stream: \(with)")
            return
        }
        pendingMemo.wholeData = contains
        pendingMemo.nextWrite += content.count-2   // there are two header, non-payload, bytes

        let msg = Message(mti: .Stream_Data_Send, source: linkLayer.localNodeID,
                          destination: with.nodeId,
                          data: content)
        linkLayer.sendMessage(msg)
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

    private func findPendingMemo(from : Message) -> StreamWritePendingDataMemo? {
        for memo in pendingOperations {
            if memo.destNodeID == from.source {
                return memo
            }
        }
        return nil
    }
    
    private func findPendingMemo(from : StreamWriteUserMemo) -> StreamWritePendingDataMemo? {
        for memo in pendingOperations {
            if memo.destNodeID == from.nodeId
                && memo.destStreamNumber == from.destStreamNumber
                && memo.sourceStreamNumber == from.sourceStreamNumber {
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
        let code : Int = ((Int)(message.data[4])<<8) + (Int)(message.data[5])
        let bufferSize = (Int)((message.data[2]<<8)+message.data[3])
        let destStreamId = (Int)(message.data[0])
        let sourceStreamId = (Int)(message.data[1])
        guard code&0x8000 != 0 else {
            StreamService.logger.warning("Stream Init Reply rejected with code \(code)")
            pendingMemo.bufferSize = bufferSize
            pendingMemo.destStreamNumber = destStreamId
            pendingMemo.sourceStreamNumber = sourceStreamId
            // create a user memo and invoke the bad reply
            let userMemo = StreamWriteUserMemo(sourceStreamNumber: (Int)(message.data[1]), destStreamNumber: (Int)(message.data[0]),
                                               nodeId: message.source, bufferSize: bufferSize
                                               )
            pendingMemo.rejectedReply(userMemo, code)
            return
        }
        // here positive reply
        StreamService.logger.debug("Stream Init Reply ok with code \(code)")
        pendingMemo.bufferSize = bufferSize
        pendingMemo.destStreamNumber = destStreamId
        pendingMemo.sourceStreamNumber = sourceStreamId
        // create a user memo and invoke the good reply
        let userMemo = StreamWriteUserMemo(sourceStreamNumber: (Int)(message.data[1]), destStreamNumber: (Int)(message.data[0]),
                                           nodeId: message.source, bufferSize: bufferSize
        )
        pendingMemo.okReply(userMemo)
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
                              destination: pendingMemo.destNodeID,
                              data: [(UInt8)(pendingMemo.destStreamNumber), (UInt8)(pendingMemo.sourceStreamNumber)])
            linkLayer.sendMessage(msg)
            return
        }
        
        // send next buffer of data
        let lowerLimit = pendingMemo.nextWrite
        let upperLimit = min(pendingMemo.wholeData.count, pendingMemo.nextWrite + pendingMemo.bufferSize)
        
        let content : [UInt8] = Array(pendingMemo.wholeData[lowerLimit..<upperLimit])
        pendingMemo.nextWrite += content.count
        let msg = Message(mti: .Stream_Data_Send, source: linkLayer.localNodeID,
                          destination: pendingMemo.destNodeID,
                          data: content)
        linkLayer.sendMessage(msg)
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
