//
//  CanLink.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os
/// Handles link-layer formatting and unformatting for CAN-frame links.
///
/// Uses a ``CanPhysicalLayer`` implementation at the ``CanFrame`` level.
///
/// This implementation handles one static Local Node and a variable number of Remote Nodes.
///  - An alias is allocated for the Local Node when the link comes up.
///  - Aliases are tracked for the Remote Nodes, but not allocated
///
public class CanLink : LinkLayer {
    
    // TODO: alias data needs to be Node-by-Node when this code supports multiple remote nodes
    static let localNodeID  = NodeID(0x05_01_01_01_03_01)  // valid default node ID, static needed to use in initialization
    var localAliasSeed : UInt64 = localNodeID.nodeID
    var localAlias : UInt = createAlias12(localNodeID.nodeID)  // 576 with NodeID(0x05_01_01_01_03_01)

    var state : State = .Initial
    
    var link : CanPhysicalLayer?
    
    final func linkPhysicalLayer( _ cpl : CanPhysicalLayer) {
        link = cpl
        cpl.registerFrameReceivedListener(receiveListener)
    }
    
    func receiveListener(frame : CanFrame) {
        switch decodeControlFrameFormat(frame) {
        case .LinkUp:
            handleReceivedLinkUp(frame)
        case .LinkCollision, .LinkError :
            logger.notice("Unexpected error report \(frame.header, format:.hex(minDigits: 8))")
        case .LinkDown :
            handleReceivedLinkDown(frame)
        case .CID :
            handleReceivedCID(frame)
        case .RID :
            handleReceivedRID(frame)
        case .AMD :
            handleReceivedAMD(frame)
        case .AME :
            handleReceivedAME(frame)
        case .AMR :
            handleReceivedAMR(frame)
        case .EIR0,
             .EIR1,
             .EIR2,
             .EIR3 :
            break   // ignored upon receipt
        case .Data :
            handleReceivedData(frame)
        case .UnknownFormat :
            logger.notice("Unexpected CAN header \(frame.header, format:.hex(minDigits: 8))")
        }
    }

    enum ControlFrame : Int {
        case RID = 0x0700
        case AMD = 0x0701
        case AME = 0x0702
        case AMR = 0x0703
        case EIR0 = 0x00710
        case EIR1 = 0x00711
        case EIR2 = 0x00712
        case EIR3 = 0x00713
        
        // note these two don't code the entire control field value (i.e. there are arguments in the lower bits)
        case CID  =  0x4000
        case Data = 0x18000

        // these are non-OLCB values used for internal signaling
        // their values have a bit set above what can come from a CAN Frame
        case LinkUp         = 0x20000
        case LinkCollision  = 0x20001
        case LinkError      = 0x20002
        case LinkDown       = 0x20003
        case UnknownFormat  = 0x21000
    }
    
    func handleReceivedLinkUp(_ frame : CanFrame) {
        // start the alias allocation in Inhibited state
        state = .Inhibited
        sendAliasAllocationSequence()
        // TODO: wait 200 msec and declare ready to go, see https://stackoverflow.com/questions/27517632/how-to-create-a-delay-in-swift
        // TODO: send AMD frame, go to Permitted state and notify upper levels
    }
        
    func handleReceivedLinkDown(_ frame : CanFrame) {
        // return to Inhibited state until link back up
        // Note: since no working link, not sending the AMR frame
        state = .Inhibited
        // TODO: notify higher levels to reset
    }
    
    func handleReceivedCID(_ frame : CanFrame) {
        // send an RID in response
        link!.sendCanFrame( CanFrame(control: ControlFrame.RID.rawValue, alias: localAlias) )
    }
    
    func handleReceivedRID(_ frame : CanFrame) {
        if (abortOnAliasCollision(frame)) { return }
    }
    
    func handleReceivedAMD(_ frame : CanFrame) {
        if (abortOnAliasCollision(frame)) { return }
    }
    
    func handleReceivedAME(_ frame : CanFrame) {
        if (abortOnAliasCollision(frame)) { return }
        if (state != .Permitted) { return }
        // check node ID
        var matchNodeID = CanLink.localNodeID
        if (frame.data.count >= 6) {
            let part1 = UInt64(frame.data[0] & 0xFF) << 40
            let part2 = UInt64(frame.data[1] & 0xFF) << 32
            let part3 = UInt64(frame.data[2] & 0xFF) << 24
            let part4 = UInt64(frame.data[3] & 0xFF) << 16
            let part5 = UInt64(frame.data[4] & 0xFF) <<  8
            let part6 = UInt64(frame.data[5] & 0xFF)
            let id = part1|part2|part2|part3|part4|part5|part6
            matchNodeID = NodeID(id)
        }
        if (CanLink.localNodeID == matchNodeID) {
            // matched, send RID
            link!.sendCanFrame( CanFrame(control: ControlFrame.AMD.rawValue, alias: localAlias) ) // TODO: add NodeID
        }
    }
    
    func handleReceivedAMR(_ frame : CanFrame) {
        if (abortOnAliasCollision(frame)) { return }
    }

    func handleReceivedData(_ frame : CanFrame) {
        if (abortOnAliasCollision(frame)) { return }
    }

    // MARK: common code
    func abortOnAliasCollision(_ frame : CanFrame) -> Bool {
        if state != .Permitted { return false }
        let receivedAlias = frame.header & 0x0000_FFF
        let abort = receivedAlias == localAlias
        if (abort ) {
            // Collision!
            link!.sendCanFrame( CanFrame(control: ControlFrame.AMR.rawValue, alias: localAlias) )
            state = .Inhibited
            // TODO: Notify and restart alias process (ala LinkUp)
        }
        return abort
    }
    
    /// Send the alias allocation sequence
    func sendAliasAllocationSequence() {
        localAliasSeed = CanLink.incrementAlias48(localAliasSeed)
        link!.sendCanFrame( CanFrame(cid: 7, nodeID: CanLink.localNodeID, alias: localAlias) )
        link!.sendCanFrame( CanFrame(cid: 6, nodeID: CanLink.localNodeID, alias: localAlias) )
        link!.sendCanFrame( CanFrame(cid: 5, nodeID: CanLink.localNodeID, alias: localAlias) )
        link!.sendCanFrame( CanFrame(cid: 4, nodeID: CanLink.localNodeID, alias: localAlias) )
        link!.sendCanFrame( CanFrame(control : ControlFrame.RID.rawValue,   alias: localAlias) )
    }
    
    /// Implements the OpenLCB preferred alias
    ///  generation mechanism:  a 48-bit computation
    ///  of x(i+1) = (2^9+1) x(i) + c  where c = 29,741,096,258,473 or 0x1B0CA37A4BA9
    static func incrementAlias48(_ oldAlias : UInt64) -> UInt64 {
        let newProduct : UInt64 = oldAlias * (UInt64(2)<<9 + UInt64(1)) + UInt64(0x1B0CA37A4BA9)
        let maskedProduct : UInt64 = newProduct & 0xFFFF_FFFF_FFFFF
        return maskedProduct;
    }
    /// Form 12 bit alias from 48-bit random number
    static func createAlias12(_ rnd : UInt64) -> UInt {
        let part1 = (rnd >> 36) & 0x0FFF
        let part2 = (rnd >> 24) & 0x0FFF
        let part3 = (rnd >> 12) & 0x0FFF
        let part4 = (rnd)       & 0x0FFF
        
        if UInt(part1^part2^part3^part4) != 0 {
            return UInt(part1^part2^part3^part4)
        } else {
            // zero is not a valid alias, so provide a non-zero value
            if UInt( (part1+part2+part3+part4)&0xFF) != 0 {
                return UInt((part1+part2+part3+part4)&0xFF)
            } else {
                return 0xAEF
            }
        }
    }
    
    func decodeControlFrameFormat(_ frame : CanFrame) -> (ControlFrame) {
        if (frame.header & 0x1800_0000) == 0x1800_0000 { // data case
            return .Data
        } else if (frame.header & 0x4_000_000) != 0 { // CID case
            return .CID
        } else {
            if let retval = ControlFrame(rawValue: Int((frame.header >> 12)&0x3FFFF) ) { return retval } // top 1 bit for out-of-band messages
            else {
                return .UnknownFormat
            }
        }
    }
    
    let logger = Logger(subsystem: "org.ardenwood.openlcblibrary", category: "CanLink")
}
