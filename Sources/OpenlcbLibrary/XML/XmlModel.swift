//
//  XmlModel.swift
//  
//
//  Created by Bob Jacobsen on 9/25/22.
//

import Foundation
import os

/**
  This is the base class for CdiModel and FdiModel.  it provides the basic read support.
 */
public class XmlModel {
    @Published public internal(set) var loading : Bool = false  // true while loading - use to show ProgressView
    @Published public internal(set) var loaded  : Bool = false  // true when loading is done and data is present
    @Published public internal(set) var endOK   : Bool = true   // if false when loaded is true, an error prevented a complete load

    internal let mservice : MemoryService
    internal let nodeID : NodeID
    internal let space : UInt8

    internal var savedDataString = ""
    @Published public internal(set) var nextReadAddress = -1
    @Published public internal(set) var readLength = 0

    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "XmlModel")

    public init (mservice : MemoryService, nodeID : NodeID, space : UInt8) {
        self.mservice = mservice
        self.nodeID = nodeID
        self.space = space
    }

    /// Start a read sequence by retrieving the memory space length,
    /// then read the contents.
    public func readLengthAndModel(nodeID: NodeID) {
        if loaded {
            return // already loaded
        }
        
        loading = true
        nextReadAddress = 0
        // first, read the length of the space
        mservice.requestSpaceLength(space: space, nodeID: nodeID, callback: memorySpaceCallback)
        
        // we'll start reading from that callback
    }
    
    /// Start a read sequence for the model, without first reading the length.
    public func readModel(nodeID: NodeID) {
        if loaded {
            return // already loaded
        }
        
        loading = true
        nextReadAddress = 0
 
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: 64, space: space, address: nextReadAddress, rejectedReply: rejectedReplyCallback, dataReply: dataReplyCallback)
        nextReadAddress = nextReadAddress+64
        mservice.requestMemoryRead(memMemo)

        // we'll start reading from that callback
    }
    
    internal func okReplyCallback(memo : MemoryService.MemoryReadMemo) {
    }
    internal func rejectedReplyCallback(memo : MemoryService.MemoryReadMemo) {
        XmlModel.logger.error("Memory service replied via rejectedReplyCallback")
        // stop input and try to process
        processAquiredText()
    }
    internal func dataReplyCallback(memo : MemoryService.MemoryReadMemo) {
        // Assume this is a Read Reply with data
        // Save the data
        if let chars = String(bytes: memo.data, encoding: .utf8) {
            savedDataString.append(chars)
        } else {
            XmlModel.logger.error("<Received data not in UTF8 form>")
            processAquiredText()
            return
        }
        // Check for end of data (< 64 and/or trailing 0 byte)
        if memo.data.count < 64 || findTrailingZero(in: memo) {
            processAquiredText()
            
            loading = false
            endOK = true
            loaded = true
            
            return
        }
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: 64, space: space, address: nextReadAddress, rejectedReply: rejectedReplyCallback, dataReply: dataReplyCallback)
        nextReadAddress = nextReadAddress+64
        mservice.requestMemoryRead(memMemo)
    }
    
    internal func findTrailingZero(in memo: MemoryService.MemoryReadMemo) -> (Bool) {
        if memo.data.contains(0x00) {
            return true
        }
        return false
    }
    
    internal func memorySpaceCallback(length : Int) {
        XmlModel.logger.trace("Memory space is \(length, privacy: .public) bytes long")
        readLength = length
        
        // do the first read and start the loop
        let memMemo = MemoryService.MemoryReadMemo(nodeID: nodeID, size: 64, space: space, address: 0, rejectedReply: rejectedReplyCallback, dataReply: dataReplyCallback)
        nextReadAddress = 64
        mservice.requestMemoryRead(memMemo)
    }

    func processAquiredText() {
        preconditionFailure("This method must be overridden")
    }

}
