//
//  CdiModel.swift
//  
//
//  Created by Bob Jacobsen on 9/4/22.
//

import Foundation
import os

public class CdiModel {
    @Published public var loading : Bool = false  // true while loading - use to show ProgressView
    @Published public var loaded  : Bool = false  // true when loading is done and data is present
    @Published public var endOK   : Bool = true   // if false when loaded is true, an error prevented a complete load

    @Published public var tree : [CdiXmlMemo] = [] // content!
    
    let mservice : MemoryService
    let nodeID : NodeID
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "CdiModel")

    public init (mservice : MemoryService, nodeID : NodeID) {
        self.mservice = mservice
        self.nodeID = nodeID
    }


    func okReplyCallback(memo : MemoryService.MemoryReadMemo) {
    }
    func rejectedReplyCallback(memo : MemoryService.MemoryReadMemo) {
        log.error("Memory service replied via rejectedReplyCallback")
    }
    func dataReplyCallback(memo : MemoryService.MemoryReadMemo) {
        // TODO: Need to OK the read
        // TODO: Save the data
        // TODO: Issue next request, if needed
    }

    public func readModel(nodeID: NodeID) {
        if loaded {
            return // already loaded
        }
        // TODO: this is just a sample-data standin
        loading = true
        
        // temporary load from sample data
        tree = CdiSampleDataAccess.sampleCdiXmlData()[0].children!
        
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: 64, space: 0x4100, address: 0, okReply: okReplyCallback, rejectedReply: rejectedReplyCallback, dataReply: dataReplyCallback)
        mservice.requestMemoryRead(memMemo)

        loading = false
        endOK = true
        loaded = true
    }
}
