//
//  MemoryService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

// TODO: Read requests are serialized, but write requests are not yet
// Datagram retry handles the link being queisced/restarted, so it's not explicitly handled here.

/// Does memory read and write requests.
///
/// Reads and writes are limited to 64 bytes at a time.
///
/// To do memory write:
/// - Create a ``MemoryWriteMemo`` and submit via ``requestMemoryWrite(_:)``
/// - Wait for either okReply or rejectedReply call back.
///
/// To do memory read:
/// - Create a ``MemoryReadMemo`` and submit via ``requestMemoryRead(_:)``
/// - Wait for either dataReply or rejectedReply call back.
/// 
final public class MemoryService {
    
    internal let dservice : DatagramService
    internal let sservice : StreamService?
    
    public init(dservice : DatagramService, sservice : StreamService? = nil) {
        self.dservice = dservice
        self.sservice = sservice
        // register to DatagramService to hear arriving datagrams
        dservice.registerDatagramReceivedListener(datagramReceivedListener)
    }
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "MemoryService")

    // Memo carries request and reply
    public struct MemoryReadMemo {
        public init(nodeID : NodeID, size : UInt8, space : UInt8, address : Int, rejectedReply : ( (_ : MemoryReadMemo) -> () )?, dataReply : ( (_ : MemoryReadMemo) -> () )? ) {
            self.nodeID = nodeID
            self.size = size
            self.space = space
            self.address = address
            self.rejectedReply = rejectedReply
            self.dataReply = dataReply
        }
        /// Node from which read is requested
        let nodeID : NodeID
        let size : UInt8  // max 64 bytes
        let space : UInt8
                            
        let address : Int
        
        /// Node received a Datagram Rejected, Terminate Due to Error or Optional Interaction Rejected that could not be recovered
        let rejectedReply : ( (_ : MemoryReadMemo) -> () )?
        let dataReply :     ( (_ : MemoryReadMemo) -> () )?

        // for convenience, data can be added or updated after creation of the memo
        var data : [UInt8] = []
     }
    
    internal var readMemos : [MemoryReadMemo] = []
    
    // convert from a space number to either
    // (false, 1-3 for in command byte) : spaces 0xFF - 0xFD
    // (true, space number) : spaces 0 - 0xFC
    internal func spaceDecode(space : UInt8) -> (Bool, UInt8) {
        if space >= 0xFD {
            return (false, space&0x03)
        } else {
            return (true, space)
        }
    }
    
    
    /// Request a read operation start.
    ///
    /// If okReply in the memo is triggered, it will be followed by a dataReply.
    /// A rejectedReply will not be followed by a dataReply.
    public func requestMemoryRead(_ memo : MemoryReadMemo) {
        // preserve the request
        readMemos.append(memo)
        
        if readMemos.count == 1 { // if there are no outstanding, only the one we just added
            requestMemoryReadNext(memo: memo)
        }
    }
    
    internal func requestMemoryReadNext(memo : MemoryReadMemo) {
        // send the read request
        var byte6 = false
        var flag : UInt8 = 0
        (byte6, flag) = spaceDecode(space: memo.space)
        let spaceFlag = byte6 ? 0x40 : flag | 0x40
        let addr2 = UInt8( (memo.address >> 24) & 0xFF )
        let addr3 = UInt8( (memo.address >> 16) & 0xFF )
        let addr4 = UInt8( (memo.address >>  8) & 0xFF )
        let addr5 = UInt8( memo.address & 0xFF )
        var data : [UInt8] = [DatagramService.ProtocolID.MemoryOperation.rawValue, spaceFlag, addr2,addr3,addr4,addr5]
        if (byte6) {
            data.append(contentsOf: [UInt8(memo.space & 0xFF)])
        }
        data.append(contentsOf: [memo.size])
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data, okReply: receivedOkReplyToMemReadDg, rejectedReply: receivedNotOKReplyToMemReadDg)
        dservice.sendDatagram(dgWriteMemo)
    }
    
    internal func receivedNotOKReplyToMemReadDg(dmemo : DatagramService.DatagramWriteMemo, flags : Int) {
        // not normal, have to handle this
        MemoryService.logger.warning("Received NAK reply to mem read datagram: \(dmemo.description)")
        
        // invoke rejected reply
        
    }

    internal func receivedOkReplyToMemReadDg(dmemo : DatagramService.DatagramWriteMemo, flags: Int) {
        MemoryService.logger.debug("Received OK reply to mem read datagram write: \(dmemo.description)")
        // check the high bit of the flags to see if this is the only reply, or something will come later
        if flags & 0x80 == 0 {
            // no reply datagram will follow, so process end of memory request
            MemoryService.logger.error("Memory Read operation rejected, not able to continue")
        }
    }

    internal func receivedNotOKReplyToWriteDg(dmemo : DatagramService.DatagramWriteMemo, flags : Int) {
        // not normal, have to handle this
        MemoryService.logger.error("Received NAK reply to mem write datagram: \(dmemo.description)")
        
        // invoke rejected reply
        memoryWriteOperationComplete(srcID: dmemo.destID, flag1: 0x08)  // flags fixed at failure
    }
    
    internal func receivedOkReplyToMemWriteDg(dmemo : DatagramService.DatagramWriteMemo, flags: Int) {
        MemoryService.logger.debug("Received OK reply to mem write datagram write: \(dmemo.description)")
        // check the high bit of the flags to see if this is the only reply, or something will come later
        if flags & 0x80 == 0 {
            // no reply datagram will follow, so process end of memory request
            memoryWriteOperationComplete(srcID: dmemo.destID, flag1: 0)  // flags fixed at success
        } // otherwise do nothing until the reply datagram arrives
    }
    
    internal func receivedNotOKReplyToWriteStr(dmemo : DatagramService.DatagramWriteMemo, flags : Int) {
        // not normal, have to handle this
        MemoryService.logger.error("Received NAK reply to mem write stream datagram: \(dmemo.description)")
        
        // invoke rejected reply
        memoryWriteOperationComplete(srcID: dmemo.destID, flag1: 0x08)  // flags fixed at failure
    }
        
    internal func memoryWriteOperationComplete(srcID: NodeID, flag1: Int) {
        // return data to requestor: first find matching memory write memo, then reply
        for index in 0..<writeMemos.count {
            if writeMemos[index].nodeID == srcID {
                let tMemoryMemo = writeMemos[index]
                writeMemos.remove(at: index)
                if (flag1 & 0x08 == 0) {
                    tMemoryMemo.okReply?(tMemoryMemo)
                } else {
                    tMemoryMemo.rejectedReply?(tMemoryMemo)
                }
                break
            }
        }
    }

    // process a datagram.  Sends the positive reply and returns true iff this is from our service.
    internal func datagramReceivedListener(dmemo: DatagramService.DatagramReadMemo) -> Bool {
        // node received a datagram, is it our service?
        guard dservice.datagramType(data: dmemo.data) == DatagramService.ProtocolID.MemoryOperation else { return false }

        // datagram must has a command value
        if dmemo.data.count < 2 {
            MemoryService.logger.error("Memory service datagram too short: \(dmemo.data.count, privacy: .public)")
            dservice.negativeReplyToDatagram(dmemo, err: 0x1041)  // Permanent error: Not implemented, subcommand is unknown.
            return true;  // error, but for our service; sent negative reply
        }
        
        // decode if read, write or some other reply
        switch dmemo.data[1] {
        case 0x50, 0x51, 0x52, 0x53, 0x58, 0x59, 0x5A, 0x5B : // read or read-error reply
            // Acknowledge the datagram
            dservice.positiveReplyToDatagram(dmemo, flags: 0x0000)
            // return data to requestor: first find matching memory read memo, then reply
            for index in 0..<readMemos.count {  // don't include readMemos.count
                if readMemos[index].nodeID == dmemo.srcID {
                    var tMemoryMemo = readMemos[index]
                    readMemos.remove(at: index)
                    // decode type of operation, hence offset for start of data
                    var offset = 6
                    if dmemo.data[1] == 0x50 || dmemo.data[1] == 0x58 {
                        offset = 7
                    }
                    
                    // are there any additional requests queued to send?
                    if readMemos.count > 0 {
                        requestMemoryReadNext(memo: readMemos[0])
                    }
                    
                    // fill data for call-back to requestor
                    if dmemo.data.count > offset {
                        tMemoryMemo.data = Array(dmemo.data[offset..<dmemo.data.count])
                    }
                    
                    // check for read or read error reply
                    if (dmemo.data[1] & 0x08 == 0) {
                        tMemoryMemo.dataReply?(tMemoryMemo)
                    } else {
                        tMemoryMemo.rejectedReply?(tMemoryMemo)
                    }
                    
                    break
                }
            }
        case 0x10, 0x11, 0x12, 0x13, 0x18, 0x19, 0x1A, 0x1B : // write datagram reply good, bad
            // Acknowledge the datagram
            dservice.positiveReplyToDatagram(dmemo, flags: 0x0000)
            
            // write complete, handle
            memoryWriteOperationComplete(srcID: dmemo.srcID, flag1: (Int) (dmemo.data[1]))
            
        case 0x30, 0x31, 0x32, 0x33, 0x38, 0x39, 0x3A, 0x3B : // write stream reply good, bad
            // Acknowledge the datagram
            dservice.positiveReplyToDatagram(dmemo, flags: 0x0000)
            
            // find the write memo, then start the stream operation
            for index in 0..<writeMemos.count {
                if writeMemos[index].nodeID == dmemo.srcID {
                    let tMemoryMemo = writeMemos[index]
                    startStreamWrite(with: tMemoryMemo)
                    break
                }
            }

        case 0x86, 0x87 : // Address Space Information Reply
            // Acknowledge the datagram
            dservice.positiveReplyToDatagram(dmemo, flags: 0x0000)

            guard spaceLengthCallback != nil else {
                MemoryService.logger.error("Address Space Information Reply received with no callback")
                return true
            }
            if dmemo.data[1] == 0x86 {
                // not present
                spaceLengthCallback?(-1)
                spaceLengthCallback = nil
                return true
            }
            // normal reply
            let address : Int = Int(dmemo.data[3]) << 24 +
                        Int(dmemo.data[4]) << 16 +
                        Int(dmemo.data[5]) << 8 +
                        Int(dmemo.data[6])
            spaceLengthCallback?(address)
            spaceLengthCallback = nil

        default:
            MemoryService.logger.error("Did not expect reply of type \(dmemo.data[1], privacy:.public)")
            // Reject the datagram
            dservice.negativeReplyToDatagram(dmemo, err: 0x1041) // Permanent error: Not implemented, subcommand is unknown.
        }
        
        return true
    }
    
    public struct MemoryWriteMemo {
        /// Node from which write is requested
        let nodeID : NodeID
        let okReply :       ( (_ : MemoryWriteMemo) -> () )?
        let rejectedReply : ( (_ : MemoryWriteMemo) -> () )?
        let progressReply : ( (_ : MemoryWriteMemo, _ : Int, _ : Int) -> () )?  // used by stream operations

        let size : UInt8  // max 64 bytes, set to 0 for stream write
        let space : UInt8
        let address : Int

        let data : [UInt8]
        
        public init(nodeID: NodeID,
                    okReply: ((_: MemoryWriteMemo) -> Void)?, rejectedReply: ((_: MemoryWriteMemo) -> Void)?,
                    progressReply: ((_: MemoryWriteMemo, _: Int, _: Int) -> Void)? = nil,
                    size: UInt8, space: UInt8, address: Int, data: [UInt8]) {
            self.nodeID = nodeID
            self.okReply = okReply
            self.rejectedReply = rejectedReply
            self.progressReply = progressReply
            self.size = size
            self.space = space
            self.address = address
            self.data = data
        }
    }

    internal var writeMemos : [MemoryWriteMemo] = []

    public func requestMemoryWrite(_ memo : MemoryWriteMemo) {
        // preserve the request
        writeMemos.append(memo)
        // create & send a write datagram
        var byte6 = false
        var flag : UInt8 = 0
        (byte6, flag) = spaceDecode(space: memo.space)
        let spaceFlag = byte6 ? 0x00 : flag | 0x00
        let addr2 = UInt8( (memo.address >> 24) & 0xFF )
        let addr3 = UInt8( (memo.address >> 16) & 0xFF )
        let addr4 = UInt8( (memo.address >>  8) & 0xFF )
        let addr5 = UInt8( memo.address & 0xFF )
        var data : [UInt8] = [DatagramService.ProtocolID.MemoryOperation.rawValue, spaceFlag, addr2,addr3,addr4,addr5]
        if (byte6) {
            data.append(contentsOf: [UInt8(memo.space & 0xFF)])
        }
        data.append(contentsOf: memo.data)
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data, okReply: receivedOkReplyToMemWriteDg, rejectedReply: receivedNotOKReplyToWriteDg)
        dservice.sendDatagram(dgWriteMemo)

    }
    
    internal func receivedOkReplyToMemWriteStrInit(dmemo : DatagramService.DatagramWriteMemo, flags: Int) {
        MemoryService.logger.debug("Received OK reply to mem write stream datagram write: \(dmemo.description)")
        // wait for the following Write Stream Reply datagram
    }
    
    internal func receivedNakReplyToMemWriteStrInit(dmemo : DatagramService.DatagramWriteMemo, flags: Int) {
        MemoryService.logger.error("Received Nak reply to mem write stream datagram write: \(dmemo.description)")
        // wait for the following Write Stream Reply datagram
    }
    

    var pendingStreamMemos = [StreamService.StreamWriteMemo : MemoryWriteMemo]()
    
    internal func receivedOkReplyToWriteStream(memo : StreamService.StreamWriteMemo) {
        MemoryService.logger.debug("Received OK reply to mem write stream operation")
        if let writeMemo = pendingStreamMemos[memo] {
            pendingStreamMemos[memo] = nil
            if let callback = writeMemo.okReply {
                callback(writeMemo)
            }
        } else {
            MemoryService.logger.warning("Could not match stream memo to write memo")
        }
    }
    
    internal func receivedNakReplyToWriteStream(memo : StreamService.StreamWriteMemo, code : Int) {
        MemoryService.logger.warning("Received not-OK reply to mem write stream operation \(code)")
        if let writeMemo = pendingStreamMemos[memo] {
            pendingStreamMemos[memo] = nil
            if let callback = writeMemo.rejectedReply {
                callback(writeMemo)
            }
        } else {
            MemoryService.logger.warning("Could not match stream memo to write memo")
        }
    }

    internal func progressReplyFromWriteStream(memo : StreamService.StreamWriteMemo, totalBytes: Int, bytesWritten: Int, finished : Bool) {
        MemoryService.logger.info("Write Stream progress: \(bytesWritten)/\(totalBytes)")
        if let writeMemo = pendingStreamMemos[memo] {
            if let callback = writeMemo.progressReply {
                callback(writeMemo, totalBytes, bytesWritten)
            }
        } else {
            MemoryService.logger.warning("Could not match stream memo to write memo")
        }
    }
    
    public func requestMemoryWriteStream(_ memo : MemoryWriteMemo) {
        // preserve the request
        writeMemos.append(memo)
        // create & send a write stream datagram
        let sourceStream : UInt8 = 0x04
        var byte6 = false
        var flag : UInt8 = 0
        (byte6, flag) = spaceDecode(space: memo.space)
        let spaceFlag = byte6 ? 0x20 : flag | 0x20
        let addr2 = UInt8( (memo.address >> 24) & 0xFF )
        let addr3 = UInt8( (memo.address >> 16) & 0xFF )
        let addr4 = UInt8( (memo.address >>  8) & 0xFF )
        let addr5 = UInt8( memo.address & 0xFF )
        var data : [UInt8] = [DatagramService.ProtocolID.MemoryOperation.rawValue, spaceFlag, addr2,addr3,addr4,addr5]
        if (byte6) {
            data.append(contentsOf: [UInt8(memo.space & 0xFF)])
        }
        data.append(contentsOf: [sourceStream])
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data, okReply: receivedOkReplyToMemWriteStrInit, rejectedReply: receivedNakReplyToMemWriteStrInit)
        dservice.sendDatagram(dgWriteMemo)
    }

    private func startStreamWrite(with memo: MemoryWriteMemo) {
        // create & start a stream request
        let streamMemo = StreamService.StreamWriteMemo(
                                            nodeId: memo.nodeID, sourceStreamNumber: 0x04, bufferSize: 8192, wholeData : memo.data, // TODO: rationalize all these source stream IDs
                                            okReply : receivedOkReplyToWriteStream,
                                            rejectedReply : receivedNakReplyToWriteStream,
                                            progressCallBack: progressReplyFromWriteStream
                                    )
        
        pendingStreamMemos[streamMemo] = memo
        
        guard let sservice = sservice else {
            MemoryService.logger.error("No StreamService available, stream write cannot procced")
            if let reply = memo.rejectedReply {
                reply(memo)
            }
            return
        }
            
        sservice.createWriteStream(withMemo: streamMemo)
    }

    
    
    private var spaceLengthCallback : ((Int) -> ())? = nil
    
    /// Request the length of a specific memory space from a remote node.
    public func requestSpaceLength(space: UInt8, nodeID : NodeID, callback : ((Int) -> ())? ) {
        guard spaceLengthCallback == nil else {
            MemoryService.logger.error("Overlapping calls to requestSpaceLength")
            return
        }
        spaceLengthCallback = callback
        // send request
        let dgReqMemo = DatagramService.DatagramWriteMemo(destID : nodeID, data: [DatagramService.ProtocolID.MemoryOperation.rawValue, 0x84, space])
        dservice.sendDatagram(dgReqMemo)
    }
   
    public func sendFreeze(nodeID : NodeID, space: UInt8) {
        // send request with no wait for reply
        let dgReqMemo = DatagramService.DatagramWriteMemo(destID : nodeID, data: [DatagramService.ProtocolID.MemoryOperation.rawValue, 0xA1, space])
        dservice.sendDatagram(dgReqMemo)
    }

    public func sendUnFreeze(nodeID : NodeID, space: UInt8) {
        // send request with no wait for reply
        let dgReqMemo = DatagramService.DatagramWriteMemo(destID : nodeID, data: [DatagramService.ProtocolID.MemoryOperation.rawValue, 0xA0, space])
        dservice.sendDatagram(dgReqMemo)
    }

    internal func arrayToInt(data: [UInt8], length: UInt8) -> (Int) {
        var result = 0
        for index in 0...Int(length-1) {
            result = result << 8
            result = result | Int(data[index])
        }
        return result
    }
    
    internal func arrayToUInt64(data: [UInt8], length: UInt8) -> (UInt64) {
        var result : UInt64 = 0
        for index in 0...Int(length-1) {
            result = result << 8
            result = result | UInt64(data[index])
        }
        return result
    }
    
    internal func arrayToString(data: [UInt8], length: UInt8) -> (String) {
        var zeroIndex = data.count
        if let temp = data.firstIndex(of: 0) {
            zeroIndex = temp
        }

        let byteCount = min(zeroIndex, Int(length) )

        if (byteCount == 0) {
            return ""
        }
        
        let result = String(bytes: Array(data[0...byteCount-1]), encoding: .utf8)
        return result ?? "<not UTF8>"
    }
    

    internal func intToArray(value: Int, length: UInt8) -> [UInt8] {
        switch length {
        case 1:
            return [UInt8(value&0xff)]
        case 2:
            return [UInt8((value>>8 )&0xff), UInt8(value&0xff)]
        case 4:
            return [UInt8((value>>24)&0xff), UInt8((value>>16)&0xff),
                    UInt8((value>>8)&0xff),  UInt8(value&0xff)]
        case 8:
            return [UInt8((value>>56)&0xff), UInt8((value>>48)&0xff),
                    UInt8((value>>40)&0xff), UInt8((value>>32)&0xff),
                    UInt8((value>>24)&0xff), UInt8((value>>16)&0xff),
                    UInt8((value>>8 )&0xff), UInt8(value&0xff)]
        default:
            return []
        }
    }
    
    internal func uInt64ToArray(value: UInt64, length: UInt8) -> [UInt8] {
        switch length {
        case 1:
            return [UInt8(value&0xff)]
        case 2:
            return [UInt8((value>>8 )&0xff), UInt8(value&0xff)]
        case 4:
            return [UInt8((value>>24)&0xff), UInt8((value>>16)&0xff),
                    UInt8((value>>8)&0xff),  UInt8(value&0xff)]
        case 8:
            return [UInt8((value>>56)&0xff), UInt8((value>>48)&0xff),
                    UInt8((value>>40)&0xff), UInt8((value>>32)&0xff),
                    UInt8((value>>24)&0xff), UInt8((value>>16)&0xff),
                    UInt8((value>>8 )&0xff), UInt8(value&0xff)]
        default:
            return []
        }
    }
    
    /// Converts a string to a UInt8 array, padding with 0 bytes as needed
    internal func stringToArray(value: String, length: UInt8) -> ([UInt8]) {
        let strToUInt8:[UInt8] = [UInt8](value.utf8)
        let byteCount = min(Int(length), strToUInt8.count)
        let contentPart = Array(strToUInt8[0..<byteCount])
        let padding = [UInt8](repeating: 0, count: Int(length))
        let both = contentPart + padding
        
        return Array(both[0..<Int(length)])
    }
    
    
}
