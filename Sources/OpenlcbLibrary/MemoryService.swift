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
    
    public init(service : DatagramService) {
        self.service = service
        // register to DatagramService to hear arriving datagrams
        service.registerDatagramReceivedListener(datagramReceivedListener)
    }
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "MemoryService")

    // Memo carries request and reply
    public struct MemoryReadMemo {
        public init(nodeID : NodeID, size : UInt8, space : UInt16, address : Int, rejectedReply : ( (_ : MemoryReadMemo) -> () )?, dataReply : ( (_ : MemoryReadMemo) -> () )? ) {
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
        let space : UInt16  // set this to 0x40SS-0x4300 i.e. space flag in top byte
                            
        let address : Int
        
        /// Node received a Datagram Rejected, Terminate Due to Error or Optional Interaction Rejected that could not be recovered
        let rejectedReply : ( (_ : MemoryReadMemo) -> () )?
        let dataReply :     ( (_ : MemoryReadMemo) -> () )?

        var data : [UInt8] = []
        let returnCode : Int = 0
        let errorType  : Int = 0  // how the error was sent // TODO: define this signaling
     }
    
    var readMemos : [MemoryReadMemo] = []
    
    /// Request a read operation start.
    ///
    /// If okReply in the memo is triggered, it will be followed by a dataReply.
    /// A rejectedReply will not be followed by a dataReply.
    public func requestMemoryRead(_ memo : MemoryReadMemo) {
        // preserve the request
        readMemos.append(memo)
        // send the read request
        let spaceFlag = UInt8( (memo.space >> 8) & 0xFF)
        let addr2 = UInt8( (memo.address >> 24) & 0xFF )
        let addr3 = UInt8( (memo.address >> 16) & 0xFF )
        let addr4 = UInt8( (memo.address >>  8) & 0xFF )
        let addr5 = UInt8( memo.address & 0xFF )
        let data : [UInt8] = [0x20, spaceFlag, addr2,addr3,addr4,addr5, memo.size]
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
        // We deliberately don't check for Read Reply so this can cover
        // e.g. Get Address Space Information Reply too
        
        // Acknowledge the datagram
        service.positiveReplyToDatagram(memo, flags: 0x0000)
        // return data to requestor: first find matching memory read memo, then reply
        for index in 0...readMemos.count {
            if readMemos[index].nodeID == memo.srcID {
                var tMemoryMemo = readMemos[index]
                readMemos.remove(at: index)
                tMemoryMemo.data = Array(memo.data[6..<memo.data.count])
                tMemoryMemo.dataReply!(tMemoryMemo)
                break
            }
        }
    }
    
    struct MemoryWriteMemo {
        /// Node from which write is requested
        let nodeID : NodeID
        let okReply :       ( (_ : MemoryWriteMemo) -> () )?
        let rejectedReply : ( (_ : MemoryWriteMemo) -> () )?

        let size : UInt8  // max 64 bytes
        let space : UInt16 // set this to 0x40SS-0x4300 i.e. space flag in top byte
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
        let spaceFlag = UInt8( (memo.space >> 8) & 0xFF)
        let addr2 = UInt8( (memo.address >> 24) & 0xFF )
        let addr3 = UInt8( (memo.address >> 16) & 0xFF )
        let addr4 = UInt8( (memo.address >>  8) & 0xFF )
        let addr5 = UInt8( memo.address & 0xFF )
        var data : [UInt8] = [0x20, spaceFlag, addr2,addr3,addr4,addr5, memo.size]
        data.append(contentsOf: memo.data) // TODO set opcode
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data)  // TODO: callbacks?
        service.sendDatagram(dgWriteMemo)

    }
    
}
