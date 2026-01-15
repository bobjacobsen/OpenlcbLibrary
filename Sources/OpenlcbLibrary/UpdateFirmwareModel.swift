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
    let node : Node
    let mservice : MemoryService
    let dservice : DatagramService
    
    let INIT_DELAY_SECONDS = 5.0

    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "UpdateFirmwareModel")

    public init (mservice : MemoryService, dservice : DatagramService, node : Node) {
        self.firmwareContent = NSData()
        self.mservice = mservice
        self.dservice = dservice
        self.node = node
        self.writeLength = firmwareContent.length
    }

    public func reset(_ stat: String) {
        status = stat
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
        mservice.sendFreeze(nodeID: node.id, space: space)
        // Wait for init complete from the node, then start.
        // Better would have been to trigger on datagram reply or Initialization Complete,
        // but some nodes are not really ready to go on InitCompl.
        // Note we need PIP results, which are automatically gathered by other code
        // after the Init Complete is seen.
        DispatchQueue.main.asyncAfter(deadline: .now() + INIT_DELAY_SECONDS) {
            UpdateFirmwareModel.logger.debug("startUpdate timer expires")
            if self.node.pipSet.contains(.STREAM_PROTOCOL) {
                // start stream processing
                self.startStreamTransfer()
            } else {
                // starts datagram transfer
                self.startDatagramTransfer()
            }
        }
    }
    
    public func cancel() {
        canceled = true
        status = "Update Cancelled"
        mservice.sendUnFreeze(nodeID: node.id, space: space)
    }
    
    fileprivate func startStreamTransfer() {
        UpdateFirmwareModel.logger.debug("startStreamTransfer")
        // send a Stream Write operation
        status = "Updating....."
        let byteArray = [UInt8](Data(self.firmwareContent))

        let memMemo = MemoryService.MemoryWriteMemo(nodeID: node.id, okReply: streamReplyCallback, rejectedReply: rejectedStreamReplyCallback,
                                                    progressReply: streamProgressCallback,
                                                    size: 0, space: UInt8(space), address: 0x00, data: byteArray)
        mservice.requestMemoryWriteStream(memMemo)
    }
    
    fileprivate func startDatagramTransfer() {
        UpdateFirmwareModel.logger.debug("startDataTransfer")
        status = "Updating..."
        sendNextDatagram()
    }
    
    fileprivate func sendNextDatagram() {
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
            
            let memMemo = MemoryService.MemoryWriteMemo(nodeID: node.id, okReply: datagramReplyCallback,
                                                        rejectedReply: rejectedDatagramReplyCallback, size: UInt8(length),
                                                        space: UInt8(space), address: nextWriteAddress, data: byteArray)
            mservice.requestMemoryWrite(memMemo)
            
            nextWriteAddress = nextWriteAddress+length
        }
    }

    fileprivate func rejectedDatagramReplyCallback(memo : MemoryService.MemoryWriteMemo) {
        UpdateFirmwareModel.logger.error("Memory service replied via rejectedReplyCallback")
        mservice.sendUnFreeze(nodeID: node.id, space: space)
        transferring = false
        status = "Update failed - rejected by node"
    }

    fileprivate func datagramReplyCallback(memo : MemoryService.MemoryWriteMemo) {
        UpdateFirmwareModel.logger.debug("dataReplyCallback")
        if canceled {
            // done early
            mservice.sendUnFreeze(nodeID: node.id, space: space)
            transferring = false
            status = "Update Cancelled"
        } else if nextWriteAddress < writeLength {
            sendNextDatagram()
        } else {
            // we're done!
            mservice.sendUnFreeze(nodeID: node.id, space: space)
            transferring = false
            status = "Update complete!"
        }
    }

    fileprivate func rejectedStreamReplyCallback(memo : MemoryService.MemoryWriteMemo) {
        UpdateFirmwareModel.logger.error("Memory service replied via rejectedStreamReplyCallback")
        mservice.sendUnFreeze(nodeID: node.id, space: space)
        transferring = false
        status = "Update failed - rejected by node"
    }
    
    fileprivate func streamReplyCallback(memo : MemoryService.MemoryWriteMemo) {
        UpdateFirmwareModel.logger.debug("streamReplyCallback")
        if canceled {
            // done early
            mservice.sendUnFreeze(nodeID: node.id, space: space)
            transferring = false
            status = "Update Cancelled"
        } else {
            // we're done!
            mservice.sendUnFreeze(nodeID: node.id, space: space)
            transferring = false
            status = "Update complete!"
        }
    }

    fileprivate func streamProgressCallback(memo : MemoryService.MemoryWriteMemo, fullLength : Int, bytesSoFar: Int) {
        nextWriteAddress = bytesSoFar
    }

}
