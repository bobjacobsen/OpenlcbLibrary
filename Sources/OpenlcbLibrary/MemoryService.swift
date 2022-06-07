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
        let node : Node
        let okReply : ( (_ : Message) -> () )?
        let rejectedReply : ( (_ : Message) -> () )?

        let data : [UInt8] = []
    }
    
    func requestMemoryRead(_ memo : MemoryReadMemo) {
        
    }

    struct MemoryWriteMemo {
        let node : Node
        let okReply : ( (_ : Message) -> () )?
        let rejectedReply : ( (_ : Message) -> () )?

        let data : [UInt8] = []
    }

    func requestMemoryWrite(_ memo : MemoryWriteMemo) {
        
    }

    // TODO: Add support for memory requests to this node.
    
}
