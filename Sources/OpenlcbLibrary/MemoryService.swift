//
//  MemoryService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

// Does memory read and write requests.
// Reads and writes are limited to 64 bytes at a time.
//
// To do memory write:
// - create a write memo and submit
// - wait for either okReply or rejectedReply call back.
//
// To do memory read:
// - create a read memo and submit
// - wait for either dataReply or rejectedReply call back.

public class MemoryService {
    
    let service : DatagramService
    
    init(service : DatagramService) {
        self.service = service
        // register to DatagramService to hear arriving datagrams
        service.registerDatagramReceivedListener(datagramReceivedListener)
    }
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "MemoryService")

    // Memo carries request and reply
    struct MemoryReadMemo {
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

        var data : [UInt8] = []
        let returnCode : Int = 0
        let errorType  : Int = 0  // how the error was sent // TODO: define this signaling
     }
    
    var readMemos : [MemoryReadMemo] = []
    
    // convert from a space number to either
    // (false, 1-3 for in command byte) : spaces 0xFF - 0xFD
    // (true, space number) : spaces 0 - 0xFC
    func spaceDecode(space : UInt8) -> (Bool, UInt8) {
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
    func requestMemoryRead(_ memo : MemoryReadMemo) {
        // preserve the request
        readMemos.append(memo)
        // send the read request
        var byte6 = false
        var flag : UInt8 = 0
        (byte6, flag) = spaceDecode(space: memo.space)
        let spaceFlag = byte6 ? 0x40 : flag | 0x40
        let addr2 = UInt8( (memo.address >> 24) & 0xFF )
        let addr3 = UInt8( (memo.address >> 16) & 0xFF )
        let addr4 = UInt8( (memo.address >>  8) & 0xFF )
        let addr5 = UInt8( memo.address & 0xFF )
        var data : [UInt8] = [0x20, spaceFlag, addr2,addr3,addr4,addr5]
        if (byte6) {
            data.append(contentsOf: [UInt8(memo.space & 0xFF)])
        }
        data.append(contentsOf: [memo.size])
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data, okReply: receivedOkReplyToWrite) // TODO: failure callback?
        service.sendDatagram(dgWriteMemo)
        
    }
    
    func receivedOkReplyToWrite(memo : DatagramService.DatagramWriteMemo) {
        // this is normal.  Wait for following response to be returned via listener
    }

    func datagramReceivedListener(memo: DatagramService.DatagramReadMemo) {
        // node received a datagram, is it our service?
        if memo.data[0] != 0x20 {
            return
        }
        
        // Acknowledge the datagram
        service.positiveReplyToDatagram(memo, flags: 0x0000)
        
        // decode if read, write or some other reply
        switch memo.data[1] {
        case 0x50, 0x51, 0x52, 0x53 : // read reply
            // return data to requestor: first find matching memory read memo, then reply
            for index in 0...readMemos.count {
                if readMemos[index].nodeID == memo.srcID {
                    var tMemoryMemo = readMemos[index]
                    readMemos.remove(at: index)
                    // decode type of operation, hence data offset
                    var offset = 6
                    if memo.data[1] == 0x50 {
                        offset = 7
                    }
                    tMemoryMemo.data = Array(memo.data[offset..<memo.data.count])
                    tMemoryMemo.dataReply!(tMemoryMemo)
                    break
                }
            }
        case 0x10, 0x11, 0x12, 0x13, 0x18, 0x19, 0x1A, 0x1B : // write reply good, bad
            // return data to requestor: first find matching memory read memo, then reply
            for index in 0...writeMemos.count {
                if writeMemos[index].nodeID == memo.srcID {
                    // var tMemoryMemo = writeMemos[index]
                    writeMemos.remove(at: index)
                    break
                }
            }
        default:
            logger.error("Did not expect reply of type \(memo.data[1], privacy:.public)")
        }
    }
    
    struct MemoryWriteMemo {
        /// Node from which write is requested
        let nodeID : NodeID
        let okReply :       ( (_ : MemoryWriteMemo) -> () )?
        let rejectedReply : ( (_ : MemoryWriteMemo) -> () )?

        let size : UInt8  // max 64 bytes
        let space : UInt8
        let address : Int

        let data : [UInt8]
        let returnCode : Int = 0
        let errorType  : Int = 0  // how the error was sent // TODO: define this signaling
    }

    var writeMemos : [MemoryWriteMemo] = []

    func requestMemoryWrite(_ memo : MemoryWriteMemo) {
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
        var data : [UInt8] = [0x20, spaceFlag, addr2,addr3,addr4,addr5]
        if (byte6) {
            data.append(contentsOf: [UInt8(memo.space & 0xFF)])
        }
        data.append(contentsOf: memo.data) // TODO set opcode
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data)
        service.sendDatagram(dgWriteMemo)

    }
    
    func arrayToInt(data: [UInt8], length: UInt8) -> (Int) {
        var result = 0
        for index in 0...Int(length-1) {
            result = result << 8
            result = result | Int(data[index])
        }
        return result
    }
    
    func arrayToString(data: [UInt8], length: UInt8) -> (String) {
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
    

    func intToArray(value: Int, length: UInt8) -> [UInt8] {
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
    
    func stringToArray(value: String, length: UInt8) -> ([UInt8]) {
        let strToUInt8:[UInt8] = [UInt8](value.utf8)
        let byteCount = min(Int(length), strToUInt8.count)
        return Array(strToUInt8[0...byteCount-1])
    }
    
    
}
