//
//  CdiModel.swift
//  
//
//  Created by Bob Jacobsen on 9/4/22.
//

import Foundation
import os

public class CdiModel : ObservableObject {
    @Published public var loading : Bool = false  // true while loading - use to show ProgressView
    @Published public var loaded  : Bool = false  // true when loading is done and data is present
    @Published public var endOK   : Bool = true   // if false when loaded is true, an error prevented a complete load

    @Published public var tree : [CdiXmlMemo] = [] // content!
    
    let mservice : MemoryService
    let nodeID : NodeID
    
    var nextReadAddress = -1
    var savedDataString = ""
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "CdiModel")

    public init (mservice : MemoryService, nodeID : NodeID) {
        self.mservice = mservice
        self.nodeID = nodeID
    }

    func okReplyCallback(memo : MemoryService.MemoryReadMemo) {
    }
    func rejectedReplyCallback(memo : MemoryService.MemoryReadMemo) {
        logger.error("Memory service replied via rejectedReplyCallback")
        // stop input and try to process
        processAquiredText()
    }
    func dataReplyCallback(memo : MemoryService.MemoryReadMemo) {
        // TODO: Save the data
        if let chars = String(bytes: memo.data, encoding: .utf8) {
            savedDataString.append(chars)
        } else {
            logger.error("received data not in UTF8 form")
            processAquiredText()
            return
        }
        // Check for end of data (< 64 and/or trailing 0 byte)
        if memo.size < 64 || findTrailingZero(in: memo) {
            processAquiredText()
            return
        }
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: 64, space: 0x4300, address: nextReadAddress, rejectedReply: rejectedReplyCallback, dataReply: dataReplyCallback)
        nextReadAddress = nextReadAddress+64
        mservice.requestMemoryRead(memMemo)
    }

    func findTrailingZero(in memo: MemoryService.MemoryReadMemo) -> (Bool) {
        if memo.data.contains(0x00) {
            return true
        }
        return false
    }
    
    func processAquiredText() {
        // actually process it into an XML tree
        tree = CdiXmlMemo.process(savedDataString.data(using: .utf8)!)[0].children! // index due tonull base node
    }
 
    public func readModel(nodeID: NodeID) {
        if loaded {
            return // already loaded
        }

        loading = true
        
        // TODO: this is just a sample-data standin
        // temporary load from sample data
        //tree = CdiSampleDataAccess.sampleCdiXmlData()[0].children!
        
        // kick off the read process
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: 64, space: 0x4300, address: 0, rejectedReply: rejectedReplyCallback, dataReply: dataReplyCallback)
        nextReadAddress = 64
        mservice.requestMemoryRead(memMemo)

        loading = false
        endOK = true
        loaded = true
    }
}
