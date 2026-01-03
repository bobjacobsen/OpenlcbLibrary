//
//  UpdateFirmwareModel.swift
//  OpenlcbLibrary
//
//  Created by Bob Jacobsen on 12/28/25.
//

import Foundation
import os

@MainActor
final public class UpdateFirmwareModel : ObservableObject, @unchecked Sendable { // shoulc change to Actor to remove @unchecked Sendable
    

    public var writeLength : Int

    @Published public internal(set) var transferring = false
    @Published public internal(set) var status = ""
    @Published public internal(set) var nextWriteAddress = 0

    var firmwareContent : NSData
    var canceled : Bool = false

    let space : UInt8 = 0xEF
    let nodeID : NodeID
    let mservice : MemoryService
    let dservice : DatagramService

    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "UpdateFirmwareModel")

    public init (mservice : MemoryService, dservice : DatagramService, nodeID : NodeID) {
        self.firmwareContent = NSData()
        self.mservice = mservice
        self.dservice = dservice
        self.nodeID = nodeID
        self.writeLength = firmwareContent.length
    }

    public func provideContent(data : NSData) {
        firmwareContent = data
        writeLength = firmwareContent.length
        canceled = false
    }
    
    public func startUpdate() {
        UpdateFirmwareModel.logger.debug("startUpdate")
        self.nextWriteAddress = 0
        transferring = true
        status = "Starting..."
        // send the Freeze datagram to the node
        mservice.sendFreeze(nodeID: nodeID, space: space)
        // wait for init complete from the node, then start
        // better would have been to trigger on datagram reply or Initialization Complete,
        // but some nodes are not really ready to go on InitCompl
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            UpdateFirmwareModel.logger.debug("startUpdate timer expires")
            self.startDataTransfer()
        }
    }
    
    public func cancel() {
        canceled = true
        status = "Update Cancelled"
        mservice.sendUnFreeze(nodeID: nodeID, space: space)
    }
    
    fileprivate func startDataTransfer() {
        UpdateFirmwareModel.logger.debug("startDataTransfer")
        status = "Updating..."
        sendNext()
    }
    
    fileprivate func sendNext() {
        DispatchQueue.main.async { [self] in
            UpdateFirmwareModel.logger.debug("sendNext")
            if canceled || !transferring {
                transferring = false
                return
            }
            
            // create and send the next data chunk
            let length = min(64, writeLength-nextWriteAddress)
            
            
            let package = self.firmwareContent[nextWriteAddress..<nextWriteAddress+length]
            let byteArray = [UInt8](Data(package))
            
            let memMemo = MemoryService.MemoryWriteMemo(nodeID: nodeID, okReply: dataReplyCallback, rejectedReply: rejectedReplyCallback, size: UInt8(length), space: UInt8(space), address: nextWriteAddress, data: byteArray)
            mservice.requestMemoryWrite(memMemo)
            
            nextWriteAddress = nextWriteAddress+length
        }
    }

    fileprivate func rejectedReplyCallback(memo : MemoryService.MemoryWriteMemo) {
        UpdateFirmwareModel.logger.error("Memory service replied via rejectedReplyCallback")
        mservice.sendUnFreeze(nodeID: nodeID, space: space)
        transferring = false
        status = "Update failed - rejected by node"
    }

    fileprivate func dataReplyCallback(memo : MemoryService.MemoryWriteMemo) {
        UpdateFirmwareModel.logger.debug("dataReplyCallback")
        if canceled {
            // done early
            mservice.sendUnFreeze(nodeID: nodeID, space: space)
            transferring = false
            status = "Update Cancelled"
        } else if nextWriteAddress < writeLength {
            sendNext()
        } else {
            // we're done!
            mservice.sendUnFreeze(nodeID: nodeID, space: space)
            transferring = false
            status = "Update complete!"
        }
    }
    
}
