//
//  MemoryService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

public class MemoryService {
    
    // Memo carries request and reply
    struct MemoryReadMemo {
        /// Node from which read is requested
        let node : Node
        let okReply :       ( (_ : MemoryReadMemo) -> () )?
        /// Node received a Datagram Rejected, Terminate Due to Error or Optional Interaction Rejected that could not be recovered
        let rejectedReply : ( (_ : MemoryReadMemo) -> () )?
        let dataReply :     ( (_ : MemoryReadMemo) -> () )?

        let data : [UInt8] = []
        let returnCode : Int = 0
        let errorType  : Int = 0  // how the error was sent // TODO: define this signaling
     }
    
    /// Request a read operation start.
    ///
    /// If okReply in the memo is triggered, it will be followed by a dataReply.
    /// A rejectedReply will not be followed by a dataReply.
    func requestMemoryRead(_ memo : MemoryReadMemo) {
        
    }

    struct MemoryWriteMemo {
        /// Node from which write is requested
        let node : Node
        let okReply :       ( (_ : MemoryWriteMemo) -> () )?
        let rejectedReply : ( (_ : MemoryWriteMemo) -> () )?

        let data : [UInt8] = []
        let returnCode : Int = 0
        let errorType  : Int = 0  // how the error was sent // TODO: define this signaling
    }

    func requestMemoryWrite(_ memo : MemoryWriteMemo) {
        
    }

    // TODO: Add support for memory requests to this node.
    
}
