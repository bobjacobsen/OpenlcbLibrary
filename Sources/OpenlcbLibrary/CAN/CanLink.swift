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
///  Multi-frame addressed messages are accumulated in parallel
///  
public class CanLink : LinkLayer {
    
    static let localNodeID  = NodeID(0x05_01_01_01_03_01)  // valid default node ID, static needed to use in initialization
    var localAliasSeed : UInt64 = localNodeID.nodeId
    var localAlias : UInt = createAlias12(localNodeID.nodeId)  // 576 with NodeID(0x05_01_01_01_03_01)

    var state : State = .Initial
    
    var link : CanPhysicalLayer?
    
    var aliasToNodeID : [UInt:NodeID] = [:]
    var nodeIdToAlias : [NodeID:UInt] = [:]

    override public init() {
        super.init()
    }
    
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

    // these are link-level concepts, so below here instead of CanFrame
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
        // send AMD frame, go to Permitted state
        link!.sendCanFrame( CanFrame(control: ControlFrame.AMD.rawValue, alias: localAlias, data: CanLink.localNodeID.toArray()) )
        state = .Permitted
        // add to map
        aliasToNodeID[localAlias] = CanLink.localNodeID
        nodeIdToAlias[CanLink.localNodeID] = localAlias
        // send AME with no NodeID to get full alias map
        link!.sendCanFrame( CanFrame(control: ControlFrame.AME.rawValue, alias: localAlias) )
        // notify upper levels
        linkStateChange(state: state)
    }
        
    func handleReceivedLinkDown(_ frame : CanFrame) {
        // return to Inhibited state until link back up
        // Note: since no working link, not sending the AMR frame
        state = .Inhibited
        // notify upper levels
        linkStateChange(state: state)
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
        // This defines an alias, so store it
        let nodeID = NodeID(frame.data)
        let alias = frame.header & 0xFFF
        aliasToNodeID[alias] = nodeID
        nodeIdToAlias[nodeID] = alias
    }
    
    func handleReceivedAME(_ frame : CanFrame) {
        if (abortOnAliasCollision(frame)) { return }
        if (state != .Permitted) { return }
        // check node ID
        var matchNodeID = CanLink.localNodeID
        if (frame.data.count >= 6) {
            matchNodeID = NodeID(frame.data)
        }
        if (CanLink.localNodeID == matchNodeID) {
            // matched, send RID
            let returnFrame = CanFrame(control: ControlFrame.AMD.rawValue, alias: localAlias, data: CanLink.localNodeID.toArray())
            link!.sendCanFrame( returnFrame )
        }
    }
    
    func handleReceivedAMR(_ frame : CanFrame) {
        if (abortOnAliasCollision(frame)) { return }
        // Alias Map Reset - drop from maps
        let nodeID = NodeID(frame.data)
        let alias = frame.header & 0xFFF
        aliasToNodeID.removeValue(forKey: alias)
        nodeIdToAlias.removeValue(forKey: nodeID)
    }

    func handleReceivedData(_ frame : CanFrame) {  // mutation to accumulate multi-frame messages
        if (abortOnAliasCollision(frame)) { return }
        // get proper MTI
        let mti = canHeaderToFullFormat(frame: frame)
        var sourceID = NodeID(0)
        if let mapped = aliasToNodeID[frame.header&0xFFF] {
            sourceID = mapped
        } else {
            logger.error("message from unknown source alias: \(frame), contine with 00.00.00.00.00.00")
        }
        
        var destID = NodeID(0)
        // handle destination for addressed messages
        if (frame.header & 0x008_000 != 0) {
            var destAlias : UInt = 0
            if (frame.data.count > 0) { destAlias |= UInt(frame.data[0] & 0x0F ) << 8 } // rm f bits
            if (frame.data.count > 1) { destAlias |= UInt(frame.data[1] & 0xFF ) }
            if let mapped = aliasToNodeID[destAlias] {
                destID = mapped
            } else {
                logger.error("message from unknown dest alias: \(frame), contine with 00.00.00.00.00.00")
            }
            
            // check for start and end bits
            let key = AccumKey(mti:mti, source:sourceID, dest:destID)
            if (frame.data[0] & 0x20 == 0) {   // TODO: handle case of never got first bit, so no entry here at next step
                // is start, create the entry in the accumulator
                accumulator[key] = []
            }
            // add this data
            if (frame.data.count > 2) {
                for byte in frame.data[2...frame.data.count-1] {
                    accumulator[key]!.append(byte)
                }
            }
            if (frame.data[0] & 0x10 == 0) {
                // is end, ship and remove accumulation
                let msg = Message(mti: mti, source: sourceID, destination: destID, data: accumulator[key]!)
                fireListeners(msg)

                // remove accumulution
                accumulator[key] = nil
            }
            
        } else {
            // forward global message
            let msg = Message(mti: mti, source: sourceID, destination: destID, data: frame.data)
            fireListeners(msg)
        }
    }
    
    override func sendMessage(_ msg : Message) {
        
        // Remap the mti
        var header = UInt( 0x19_000_000 | ((msg.mti.rawValue & 0xFFF) << 12) )
 
        if let alias = nodeIdToAlias[msg.source] { // might not know it if error
            header |= (alias & 0xFFF)
        } else {
            logger.error("Did not know source = \(msg.source) on global send")
        }

        // Is a destination address needed? Could be long message
        if (msg.isAddressed()) {
            if let alias = nodeIdToAlias[msg.destination ?? NodeID(0)] { // might not know it?
                // address and have alias, break up data
                let dataSegments = segmentDataArray(alias, msg.data)
                for content in dataSegments {
                    // send the resulting frame
                    let frame = CanFrame(header: header, data: content)
                    link!.sendCanFrame( frame )
                }
            } else {
                logger.error("Oon't know alias for destination = \(msg.destination ?? NodeID(0))")
            }
        } else {
            // global still can hold data; assume length is correct by protocol
            // send the resulting frame
            let frame = CanFrame(header: header, data: msg.data)
            link!.sendCanFrame( frame )
        }
        

        // TODO: reformat datagrams
    }
    
    // segment data into zero or more arrays of no more than 8 bytes, with the alias at the start of each
    final func segmentDataArray(_ alias : UInt, _ data : [UInt8]) ->[[UInt8]] {
        let part0 = UInt8( (alias >> 8) & 0xF)
        let part1 = UInt8( alias & 0xFF )
        let nSegments = (data.count+5) / 6 // the +5 is since integer division takes the floor value
        if (nSegments == 0 ) { return [[part0, part1]] }
        if (nSegments == 1 ) {
            return [[part0, part1]+data]
        }
        // multiple frames
        var retval : [[UInt8]] = []
        for i in 0...nSegments-2 { // first enty of 2 has full data
            let nextEntry = [part0 | 0x30, part1]+Array(data[i*6 ... i*6+5])
            retval.append(nextEntry)
        }
        // add the last
        let lastEntry = [part0 | 0x20, part1]+Array(data[6*(nSegments-1) ... data.count-1])
        retval.append(lastEntry)
        // mark first (last already done above)
        retval[0][0] &= ~0x20
        
        return retval
    }
    
    // MARK: common code
    func abortOnAliasCollision(_ frame : CanFrame) -> Bool {
        if state != .Permitted { return false }
        let receivedAlias = frame.header & 0x0000_FFF
        let abort = (receivedAlias == localAlias)
        if (abort ) {
            // Collision!
            link!.sendCanFrame( CanFrame(control: ControlFrame.AMR.rawValue, alias: localAlias, data: CanLink.localNodeID.toArray()) )
            state = .Inhibited
            // TODO: Notify and restart alias process (ala LinkDown, LinkUp? )
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
                return 0xAEF // Why'd you say Burma?
            }
        }
    }
    
    func decodeControlFrameFormat(_ frame : CanFrame) -> (ControlFrame) {
        if (frame.header & 0x0800_0000) == 0x0800_0000 { // data case; not checking leading 1 bit
            return .Data
        } else if (frame.header & 0x4_000_000) != 0 { // CID case
            return .CID
        } else {
            if let retval = ControlFrame(rawValue: Int((frame.header >> 12)&0x2FFFF) ) { return retval } // top 1 bit for out-of-band messages
            else {
                return .UnknownFormat
            }
        }
    }
    
    // returns a full 16-bit MTI from the full 29 bits of a CAN header
    func canHeaderToFullFormat(frame : CanFrame) -> MTI {
        let frameType = (frame.header >> 24) & 0x7
        let canMTI = Int((frame.header >> 12) & 0xFFF)
        
        if frameType == 1 {
            if let okMTI = MTI(rawValue: canMTI) {
                return okMTI
            } else {
                logger.error("unhandled canMTI: \(frame), marked Unknown")
                return MTI.Unknown
            }
        } else if (frameType >= 2 && 5 >= frameType) {
            // datagram type - we don't address the subtypes here
            return MTI.Datagram
        } else {
            // not handling reserver and stream type except to log
            logger.error("unhandled canMTI: \(frame), marked Unknown")
            return MTI.Unknown
        }
    }
    
    // struct that holds the ID for accumulating a mult-part message:
    //   - MTI
    //   - Source
    //   - Destination
    // Together these uniquely identify a stream of frames that need to be assembled into a message
    struct AccumKey : Hashable, Equatable {
        let mti: MTI
        let source: NodeID
        let dest: NodeID
    }
    var accumulator : [AccumKey: [UInt8]] = [:]

    let logger = Logger(subsystem: "org.ardenwood.openlcblibrary", category: "CanLink")
}
