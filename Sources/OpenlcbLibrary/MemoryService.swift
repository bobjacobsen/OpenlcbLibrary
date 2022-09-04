//
//  MemoryService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

public class MemoryService {
    
    let service : DatagramService
    
    public init(service : DatagramService) {
        self.service = service
    }
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "MemoryService")

    // Memo carries request and reply
    public struct MemoryReadMemo {
        public init(nodeID : NodeID, size : UInt8, space : UInt16, address : Int, okReply : ( (_ : MemoryReadMemo) -> () )?, rejectedReply : ( (_ : MemoryReadMemo) -> () )?, dataReply : ( (_ : MemoryReadMemo) -> () )? ) {
            self.nodeID = nodeID
            self.size = size
            self.space = space
            self.address = address
            self.okReply = okReply
            self.rejectedReply = rejectedReply
            self.dataReply = dataReply
        }
        /// Node from which read is requested
        let nodeID : NodeID
        let size : UInt8  // max 64 bytes
        let space : UInt16 // set this to 0x40SS-0x4300 i.e. space flag in top byte
        let address : Int
        
        let okReply :       ( (_ : MemoryReadMemo) -> () )?
        /// Node received a Datagram Rejected, Terminate Due to Error or Optional Interaction Rejected that could not be recovered
        let rejectedReply : ( (_ : MemoryReadMemo) -> () )?
        let dataReply :     ( (_ : MemoryReadMemo) -> () )?

        let data : [UInt8] = []
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
        let data : [UInt8] = [0x20, spaceFlag, addr2,addr3,addr4, addr5, memo.size]
        let dgWriteMemo = DatagramService.DatagramWriteMemo(destID : memo.nodeID, data: data)
        service.sendDatagram(dgWriteMemo)
        
    }

    struct MemoryWriteMemo {
        /// Node from which write is requested
        let nodeID : NodeID
        let okReply :       ( (_ : MemoryWriteMemo) -> () )?
        let rejectedReply : ( (_ : MemoryWriteMemo) -> () )?

        let data : [UInt8] = []
        let returnCode : Int = 0
        let errorType  : Int = 0  // how the error was sent // TODO: define this signaling
    }

    var writeMemos : [MemoryWriteMemo] = []

    func requestMemoryWrite(_ memo : MemoryWriteMemo) {
        // preserve the request
        writeMemos.append(memo)

    }
    
}
