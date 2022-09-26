//
//  CdiModel.swift
//  
//
//  Created by Bob Jacobsen on 9/4/22.
//

import Foundation
import os

final public class CdiModel : XmlModel, ObservableObject {
    
    @Published public var tree : [CdiXmlMemo] = [] // content!
            
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "CdiModel")
    
    public init (mservice : MemoryService, nodeID : NodeID ) {
        super.init(mservice: mservice, nodeID: nodeID, space: 0xFF)
    }

    override internal func processAquiredText() {
        // actually process it into an XML tree
        tree = CdiXmlMemo.process(savedDataString.data(using: .utf8)!)[0].children! // index due to null base node
    }

    public func writeInt(value : Int, at: Int, space: UInt8, length: UInt8) {
        let memMemo = MemoryService.MemoryWriteMemo(nodeID: nodeID, okReply: {_ in}, rejectedReply: {_ in }, size: length, space: space, address: at, data: mservice.intToArray(value: value, length: length))
        
        mservice.requestMemoryWrite(memMemo)
    }
    
    // An event is written as an _unsigned_ quantity to fit in 64 bits
    public func writeEvent(value : UInt64, at: Int, space: UInt8, length: UInt8) {
        let memMemo = MemoryService.MemoryWriteMemo(nodeID: nodeID, okReply: {_ in}, rejectedReply: {_ in }, size: length, space: space, address: at, data: mservice.uInt64ToArray(value: value, length: length))
        
        mservice.requestMemoryWrite(memMemo)
    }
    
    public func writeString(value : String, at: Int, space: UInt8, length: UInt8) {
        let memMemo = MemoryService.MemoryWriteMemo(nodeID: nodeID, okReply: {_ in}, rejectedReply: {_ in }, size: length, space: space, address: at, data: mservice.stringToArray(value: value, length: length))
        
        mservice.requestMemoryWrite(memMemo)
    }
    
    public func readInt(from: Int, space: UInt8, length: UInt8, action: @escaping (Int)->()) {
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: length, space: space, address: from,
                                                   rejectedReply: {_ in
            CdiModel.logger.error("Rejected reply to readInt of \(from, privacy: .public)")
        },
                                                   dataReply: {memo in
            action(self.mservice.arrayToInt(data:memo.data, length: length))
        })
        mservice.requestMemoryRead(memMemo)
    }
    
    // An event is read as an _unsigned_ quantity to fit in 64 bits
    public func readEvent(from: Int, space: UInt8, length: UInt8, action: @escaping (UInt64)->()) {
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: length, space: space, address: from,
                                                   rejectedReply: {_ in
            CdiModel.logger.error("Rejected reply to readInt of \(from, privacy: .public)")
        },
                                                   dataReply: {memo in
            action(self.mservice.arrayToUInt64(data:memo.data, length: length))
        })
        mservice.requestMemoryRead(memMemo)
    }
    
    public func readString(from: Int, space: UInt8, length: UInt8, action: @escaping (String)->()) {
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: length, space: space, address: from,
                                                   rejectedReply: {_ in
            CdiModel.logger.error("Rejected reply to readString of \(from, privacy: .public)")
        },
                                                   dataReply: {memo in
            action(self.mservice.arrayToString(data:memo.data, length: length))
        })
        mservice.requestMemoryRead(memMemo)
    }
    
}
