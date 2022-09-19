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
/// Uses a ``CanPhysicalLayer`` implementation at the ``CanFrame`` layer.
///
/// This implementation handles one static Local Node and a variable number of Remote Nodes.
///  - An alias is allocated for the Local Node when the link comes up.
///  - Aliases are tracked for the Remote Nodes, but not allocated
///
///  Multi-frame addressed messages are accumulated in parallel
///  
final public class CanLink : LinkLayer {
    
    var localAliasSeed : UInt64
    var localAlias : UInt

    var state : State = .Initial
    
    var link : CanPhysicalLayer?
    
    // the local alias <-> NodeID mapping
    var aliasToNodeID : [UInt:NodeID] = [:]
    var nodeIdToAlias : [NodeID:UInt] = [:]
    
    var nextInternallyAssignedNodeID : UInt64 = 1

    public init(localNodeID : NodeID) {
        self.localAliasSeed = localNodeID.nodeId
        self.localAlias = CanLink.createAlias12(localAliasSeed)
        super.init(localNodeID)
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

    // these are link-layer concepts, so below here instead of CanFrame
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
        defineAndReserveAlias()
        // notify upper layers
        linkStateChange(state: state)
    }
        
    func defineAndReserveAlias() {
        sendAliasAllocationSequence()
        
        // TODO: wait 200 msec and declare ready to go, see https://stackoverflow.com/questions/27517632/how-to-create-a-delay-in-swift and https://nilcoalescing.com/blog/DelayAnAsyncTaskInSwift/?utm_source=canopas-stack-weekly
        // send AMD frame, go to Permitted state
        link!.sendCanFrame( CanFrame(control: ControlFrame.AMD.rawValue, alias: localAlias, data: localNodeID.toArray()) )
        state = .Permitted
        // add to map
        aliasToNodeID[localAlias] = localNodeID
        nodeIdToAlias[localNodeID] = localAlias
        // send AME with no NodeID to get full alias map
        link!.sendCanFrame( CanFrame(control: ControlFrame.AME.rawValue, alias: localAlias) )
    }
    
    func handleReceivedLinkDown(_ frame : CanFrame) {
        // return to Inhibited state until link back up
        // Note: since no working link, not sending the AMR frame
        state = .Inhibited
        // notify upper levels
        linkStateChange(state: state)
    }
    
    func handleReceivedCID(_ frame : CanFrame) {
        // Does this carry our alias?
        if (frame.header & 0xFFF) != localAlias {return} // no match
        // send an RID in response
        link!.sendCanFrame( CanFrame(control: ControlFrame.RID.rawValue, alias: localAlias) )
    }
    
    func handleReceivedRID(_ frame : CanFrame) {
        if (checkAndHandleAliasCollision(frame)) { return }
    }
    
    func handleReceivedAMD(_ frame : CanFrame) {
        if (checkAndHandleAliasCollision(frame)) { return }
        // This defines an alias, so store it
        let nodeID = NodeID(frame.data)
        let alias = frame.header & 0xFFF
        aliasToNodeID[alias] = nodeID
        nodeIdToAlias[nodeID] = alias
    }
    
    func handleReceivedAME(_ frame : CanFrame) {
        if (checkAndHandleAliasCollision(frame)) { return }
        if (state != .Permitted) { return }
        // check node ID
        var matchNodeID = localNodeID
        if (frame.data.count >= 6) {
            matchNodeID = NodeID(frame.data)
        }
        if (localNodeID == matchNodeID) {
            // matched, send RID
            let returnFrame = CanFrame(control: ControlFrame.AMD.rawValue, alias: localAlias, data: localNodeID.toArray())
            link!.sendCanFrame( returnFrame )
        }
    }
    
    func handleReceivedAMR(_ frame : CanFrame) {
        if (checkAndHandleAliasCollision(frame)) { return }
        // Alias Map Reset - drop from maps
        let nodeID = NodeID(frame.data)
        let alias = frame.header & 0xFFF
        aliasToNodeID.removeValue(forKey: alias)
        nodeIdToAlias.removeValue(forKey: nodeID)
    }

    func handleReceivedData(_ frame : CanFrame) {
        if (checkAndHandleAliasCollision(frame)) { return }
        // get proper MTI
        let mti = canHeaderToFullFormat(frame: frame)
        var sourceID = NodeID(0)
        if let mapped = aliasToNodeID[frame.header&0xFFF] {
            sourceID = mapped
        } else {
            // special case for JMRI, which sends VerifiedNodeID but not AMD
            if mti == MTI.Verified_NodeID {
                sourceID = NodeID(frame.data)
                logger.info("Verified_NodeID from unknown source alias: \(frame, privacy: .public), continue with observed ID \(sourceID, privacy: .public)")
            } else {
                sourceID = NodeID(nextInternallyAssignedNodeID)
                nextInternallyAssignedNodeID += 1
                logger.error("message from unknown source alias: \(frame, privacy: .public), continue with created ID \(sourceID, privacy: .public)")
            }
            // register that internally-generated nodeID-alias association
            aliasToNodeID[frame.header&0xFFF] = sourceID
            nodeIdToAlias[sourceID] = frame.header&0xFFF
        }
        
        var destID = NodeID(0)
        // handle destination for addressed messages
        let dgCode = frame.header & 0x00F_000_000
        if (frame.header & 0x008_000 != 0 || (dgCode >= 0x00A_000_000 && dgCode <= 0x00F_000_000)) {  // Addressed bit is active 1
            // decoder regular addressed message from Datagram
            if (dgCode >= 0x00A_000_000 && dgCode <= 0x00F_000_000) {
                // datagram case

                let destAlias : UInt = (frame.header & 0x00_FFF_000 ) >> 12
                if let mapped = aliasToNodeID[destAlias] {
                    destID = mapped
                } else {
                    destID = NodeID(nextInternallyAssignedNodeID)
                    logger.error("message from unknown dest alias: \(frame, privacy: .public), continue with \(destID, privacy: .public)")
                    // register that internally-generated nodeID-alias association
                    aliasToNodeID[destAlias] = destID
                    nodeIdToAlias[destID] = destAlias
                }
                // check for start and end bits
                let key = AccumKey(mti:mti, source:sourceID, dest:destID)
                if (dgCode == 0x00A_000_000 || dgCode == 0x00B_000_000 ) {
                    // start of message, create the entry in the accumulator
                    accumulator[key] = []
                } else {
                    // not start frame
                    // check for never properly started, this is an errorn
                    guard accumulator[key] != nil else {
                        // have not-start frame, but never started
                        logger.error("Dropping non-start datagram frame without accumulation started: \(frame, privacy: .public)")
                        return // early return to stop processing of this grame
                    }
                }
                // add this data
                if (frame.data.count > 0) {
                    accumulator[key]!.append(contentsOf: frame.data)
                }
                if (dgCode == 0x00A_000_000 || dgCode == 0x00D_000_000 ) {
                    // is end, ship and remove accumulation
                    let msg = Message(mti: mti, source: sourceID, destination: destID, data: accumulator[key]!)
                    fireListeners(msg)
                    
                    // remove accumulution
                    accumulator[key] = nil
                }

            } else {
                // addressed message case
                var destAlias : UInt = 0
                if (frame.data.count > 0) { destAlias |= UInt(frame.data[0] & 0x0F ) << 8 } // rm f bits
                if (frame.data.count > 1) { destAlias |= UInt(frame.data[1] & 0xFF ) }
                if let mapped = aliasToNodeID[destAlias] {
                    destID = mapped
                } else {
                    destID = NodeID(nextInternallyAssignedNodeID)
                    logger.error("message from unknown dest alias: \(frame, privacy: .public), continue with \(destID, privacy: .public)")
                    // register that internally-generated nodeID-alias association
                    aliasToNodeID[destAlias] = destID
                    nodeIdToAlias[destID] = destAlias
                }
                
                // check for start and end bits
                let key = AccumKey(mti:mti, source:sourceID, dest:destID)
                if (frame.data[0] & 0x20 == 0) {
                    // is start, create the entry in the accumulator
                    accumulator[key] = []
                } else {
                    // not start frame
                    // check for first bit set never seen
                    guard accumulator[key] != nil else {
                        // have not-start frame, but never started
                        logger.error("Dropping non-start frame without accumulation started: \(frame, privacy: .public)")
                        return // early return to stop processing of this grame
                    }
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
            } // end addressed message case
            
        } else {
            // forward global message
            let msg = Message(mti: mti, source: sourceID, destination: destID, data: frame.data)
            fireListeners(msg)
        }
    }
    
    override func sendMessage(_ msg : Message) {
        // special case for datagram
        if msg.mti == .Datagram {
            var header = UInt(0x10_000_000)
            // datagram headers are
            //          1Adddsss - one frame
            //          1Bdddsss - first frame
            //          1Cdddsss - middle frame
            //          1Ddddsss - last frame
            if let sssAlias = nodeIdToAlias[msg.source] { // might not know it if error
                header |= (UInt(sssAlias) & 0xFFF)
            } else {
                logger.error("Did not know source = \(msg.source) on datagram send")
            }
            if let dddAlias = nodeIdToAlias[msg.destination!] { // might not know it if error
                header |= (UInt(dddAlias) & 0xFFF) << 12
            } else {
                logger.error("Did not know destination = \(msg.source) on datagram send")
            }
            
            if msg.data.count <= 8 {
                // single frame
                header |= 0x0A_000_000
                let frame = CanFrame(header: header, data: msg.data)
                link!.sendCanFrame( frame )
            } else {
                // multi-frame datagram
                let dataSegments = segmentDatagramDataArray(msg.data)
                // send the first one
                var frame = CanFrame(header: header|0x0B_000_000, data: dataSegments[0])
                link!.sendCanFrame( frame )
                // send middles
                if (dataSegments.count >= 3) {
                    for index in 1...dataSegments.count - 2 { // upper limit leaves one
                        frame = CanFrame(header: header|0x0C_000_000, data: dataSegments[index])
                        link!.sendCanFrame( frame )
                    }
                }
                // send last one
                frame = CanFrame(header: header|0x0D_000_000, data: dataSegments[dataSegments.count - 1])
                link!.sendCanFrame( frame )
            }
        } else {
            // all non-datagram cases
            // Remap the mti
            var header = UInt( 0x19_000_000 | ((msg.mti.rawValue & 0xFFF) << 12) )
            
            if let alias = nodeIdToAlias[msg.source] { // might not know it if error
                header |= (alias & 0xFFF)
            } else {
                logger.error("Did not know source = \(msg.source) on message send")
            }
            
            // Is a destination address needed? Could be long message
            if (msg.isAddressed()) {
                if let alias = nodeIdToAlias[msg.destination ?? NodeID(0)] { // might not know it?
                    // address and have alias, break up data
                    let dataSegments = segmentAddressedDataArray(alias, msg.data)
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
            
        }
    }
   
    // segment data into zero or more arrays of no more than 8 bytes for datagram
    final func segmentDatagramDataArray(_ data : [UInt8]) ->[[UInt8]] {
        let nSegments = (data.count+7) / 8 // the +7 is since integer division takes the floor value
        if (nSegments == 0 ) {
            return [[]]
        }
        if (nSegments == 1 ) {
            return [data]
        }
        // multiple frames
        var retval : [[UInt8]] = []
        for i in 0...nSegments-2 { // first enty of 2 has full data
            let nextEntry = Array(data[i*8 ... i*8+7])
            retval.append(nextEntry)
        }
        // add the last
        let lastEntry = Array(data[8*(nSegments-1) ... data.count-1])
        retval.append(lastEntry)
        
        return retval
    }

    // segment data into zero or more arrays of no more than 8 bytes, with the alias at the start of each, for addressed non-datagram messages
    final func segmentAddressedDataArray(_ alias : UInt, _ data : [UInt8]) ->[[UInt8]] {
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
    func checkAndHandleAliasCollision(_ frame : CanFrame) -> Bool {
        if state != .Permitted { return false }
        let receivedAlias = frame.header & 0x0000_FFF
        let abort = (receivedAlias == localAlias)
        if (abort ) {
            // Collision! \\ TODO: are we doing the right thing here on alias collision?
            logger.notice("alias collision in frame \(frame, privacy: .public), we restart with AMR and attempt to get new alias")
            link!.sendCanFrame( CanFrame(control: ControlFrame.AMR.rawValue, alias: localAlias, data: localNodeID.toArray()) )
            // Standard 6.2.5
            state = .Inhibited
            // attempt to get a new alias and go back to .Permitted
            localAliasSeed = CanLink.incrementAlias48(localAliasSeed)
            localAlias = CanLink.createAlias12(localAliasSeed)
            defineAndReserveAlias()
        }
        return abort
    }
    
    /// Send the alias allocation sequence
    func sendAliasAllocationSequence() {
        link!.sendCanFrame( CanFrame(cid: 7, nodeID: localNodeID, alias: localAlias) )
        link!.sendCanFrame( CanFrame(cid: 6, nodeID: localNodeID, alias: localAlias) )
        link!.sendCanFrame( CanFrame(cid: 5, nodeID: localNodeID, alias: localAlias) )
        link!.sendCanFrame( CanFrame(cid: 4, nodeID: localNodeID, alias: localAlias) )
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

    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "CanLink")
}
