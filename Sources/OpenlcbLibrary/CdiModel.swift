//
//  CdiModel.swift
//  
//
//  Created by Bob Jacobsen on 9/4/22.
//

import Foundation
import os

final public class CdiModel : ObservableObject {
    @Published public internal(set) var loading : Bool = false  // true while loading - use to show ProgressView
    @Published public internal(set) var loaded  : Bool = false  // true when loading is done and data is present
    @Published public internal(set) var endOK   : Bool = true   // if false when loaded is true, an error prevented a complete load
    
    @Published public var tree : [CdiXmlMemo] = [] // content!
    
    internal let mservice : MemoryService
    internal let nodeID : NodeID
    
    @Published public internal(set) var nextReadAddress = -1
    @Published public internal(set) var cdiLength = 0
    
    internal var savedDataString = ""
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "CdiModel")
    
    public init (mservice : MemoryService, nodeID : NodeID) {
        self.mservice = mservice
        self.nodeID = nodeID
    }
    
    internal func okReplyCallback(memo : MemoryService.MemoryReadMemo) {
    }
    internal func rejectedReplyCallback(memo : MemoryService.MemoryReadMemo) {
        CdiModel.logger.error("Memory service replied via rejectedReplyCallback")
        // stop input and try to process
        processAquiredText()
    }
    internal func dataReplyCallback(memo : MemoryService.MemoryReadMemo) {
        // Assume this is a Read Reply with data
        // Save the data
        if let chars = String(bytes: memo.data, encoding: .utf8) {
            savedDataString.append(chars)
        } else {
            CdiModel.logger.error("<Received data not in UTF8 form>")
            processAquiredText()
            return
        }
        // Check for end of data (< 64 and/or trailing 0 byte)
        if memo.size < 64 || findTrailingZero(in: memo) {
            processAquiredText()
            
            loading = false
            endOK = true
            loaded = true
            
            return
        }
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: 64, space: 0xFF, address: nextReadAddress, rejectedReply: rejectedReplyCallback, dataReply: dataReplyCallback)
        nextReadAddress = nextReadAddress+64
        mservice.requestMemoryRead(memMemo)
    }
    
    internal func findTrailingZero(in memo: MemoryService.MemoryReadMemo) -> (Bool) {
        if memo.data.contains(0x00) {
            return true
        }
        return false
    }
    
    internal func processAquiredText() {
        // actually process it into an XML tree
        tree = CdiXmlMemo.process(savedDataString.data(using: .utf8)!)[0].children! // index due to null base node
    }
    
    internal func memorySpaceCallback(length : Int) {
        CdiModel.logger.trace("Memory space 0xFF is \(length, privacy: .public) bytes long")
        cdiLength = length

        // do the first read and start the loop
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: 64, space: 0xFF, address: 0, rejectedReply: rejectedReplyCallback, dataReply: dataReplyCallback)
        nextReadAddress = 64
        mservice.requestMemoryRead(memMemo)
    }
              
    public func readModel(nodeID: NodeID) {
        if loaded {
            return // already loaded
        }
        
        loading = true
        nextReadAddress = 0
        // first, read the length of the space
        mservice.requestSpaceLength(space: 0xFF, nodeID: nodeID, callback: memorySpaceCallback)
        
        // we'll start reading from that callback
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
