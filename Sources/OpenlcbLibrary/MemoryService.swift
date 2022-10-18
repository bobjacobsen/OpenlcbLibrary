//
//  MemoryService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

// TODO: Read requests are serialized, but write requests are not yet
// TODO: (Restart) Datagram retry will (hopefully) get the read datagram there, but what if we lose the reply datagram with data back? Can't catch restart, because sometimes restart is OK.  Time out and fail?  Time out and retry N times?

/// Does memory read and write requests.
/// Reads and writes are limited to 64 bytes at a time.
///
/// To do memory write:
/// - create a write memo and submit
/// - wait for either okReply or rejectedReply call back.
///
/// To do memory read:
/// - create a read memo and submit
/// - wait for either dataReply or rejectedReply call back.
final public class MemoryService {
    
    internal let service : DatagramService
    
    public init(service : DatagramService) {
        self.service = service
        // register to DatagramService to hear arriving datagrams
        service.registerDatagramReceivedListener(datagramReceivedListener)
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
        
        if readMemos.count == 1 {
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
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data, okReply: receivedOkReplyToWrite)
        service.sendDatagram(dgWriteMemo)
    }
    
    internal func receivedOkReplyToWrite(memo : DatagramService.DatagramWriteMemo) {
        // this is normal.  Wait for following response to be returned via listener
    }

    // process a datagram.  Sends the positive reply and returns true iff this is from our service.
    internal func datagramReceivedListener(dmemo: DatagramService.DatagramReadMemo) -> Bool {
        // node received a datagram, is it our service?
        guard service.datagramType(data: dmemo.data) == DatagramService.ProtocolID.MemoryOperation else { return false }

        // datagram must has a command value
        if dmemo.data.count < 2 {
            MemoryService.logger.error("Memory service datagram too short: \(dmemo.data.count, privacy: .public)")
            service.negativeReplyToDatagram(dmemo, err: 0x1041)
            return true;  // error, but for our service; sent negative reply
        }
        // Acknowledge the datagram
        service.positiveReplyToDatagram(dmemo, flags: 0x0000)
        
        // decode if read, write or some other reply
        switch dmemo.data[1] {
        case 0x50, 0x51, 0x52, 0x53, 0x58, 0x59, 0x5A, 0x5B : // read or read-error reply
            // return data to requestor: first find matching memory read memo, then reply
            for index in 0...readMemos.count {
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
        case 0x10, 0x11, 0x12, 0x13, 0x18, 0x19, 0x1A, 0x1B : // write reply good, bad
            // return data to requestor: first find matching memory write memo, then reply
            for index in 0...writeMemos.count {
                if writeMemos[index].nodeID == dmemo.srcID {
                    let tMemoryMemo = writeMemos[index]
                    writeMemos.remove(at: index)
                    if (dmemo.data[1] & 0x08 == 0) {
                        tMemoryMemo.okReply?(tMemoryMemo)
                    } else {
                        tMemoryMemo.rejectedReply?(tMemoryMemo)
                    }
                    break
                }
            }
        case 0x86, 0x87 : // Address Space Information Reply
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
        }
        
        return true
    }
    
    public struct MemoryWriteMemo {
        /// Node from which write is requested
        let nodeID : NodeID
        let okReply :       ( (_ : MemoryWriteMemo) -> () )?
        let rejectedReply : ( (_ : MemoryWriteMemo) -> () )?

        let size : UInt8  // max 64 bytes
        let space : UInt8
        let address : Int

        let data : [UInt8]
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
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data)
        service.sendDatagram(dgWriteMemo)

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
        service.sendDatagram(dgReqMemo)
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
