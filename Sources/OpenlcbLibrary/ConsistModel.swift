//
//  ConsistModel.swift
//
//  Created by Bob Jacobsen on 8/1/22.
//

import Foundation
import os

/// Represents a single consist.
///
/// Provides support for reading and writing consists in the command station node.
final public class ConsistModel : ObservableObject, Processor {
    
    @Published public var forLoco : NodeID = NodeID(0)
    @Published public var consist : [ConsistEntryModel] = []
    
    let linkLayer : LinkLayer
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ConsistModel")

    public init(linkLayer : LinkLayer) {
        self.linkLayer = linkLayer
    }
    
    /// Represent a single element of a consist
    final public class ConsistEntryModel : ObservableObject {
        @Published public var childLoco : NodeID
        
        @Published public var reverse : Bool = false
        @Published public var echoF0 : Bool = false
        @Published public var echoFn : Bool = false
        @Published public var hide : Bool = false
        
        public var id = UUID()
        
        public convenience init(childLoco : NodeID) {
            self.init(childLoco : childLoco, reverse : false, echoF0 : false, echoFn : false, hide: false)
        }
        
        init(childLoco : NodeID, reverse : Bool, echoF0 : Bool, echoFn : Bool, hide: Bool) {
            self.childLoco = childLoco
            self.reverse = reverse
            self.echoF0 = echoF0
            self.echoFn = echoFn
            self.hide = hide
        }

    }
    
    enum FetchConsistState {
        case Idle
        case AwaitingReadReply
    }
    var fetchConsistState : FetchConsistState = .Idle
    var remainingNodes : [NodeID] = []  // workspace

    /// Kick off the process of reading in a single-level, single-link consist
    /// starting with the head locomotive.
    ///
    /// This does direct Query Node operations until a null is returned,
    /// without first getting the count.
    public func fetchConsist() {
        // clear the existing model
        consist = []
        // Kick off the read with the first one
        fetchConsistState = .AwaitingReadReply
        let message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x03, 0x00]) // to head of consist
        linkLayer.sendMessage(message)
        // now it heads over to the consist processor to wait for the reply
    }
    
    /// Add a loco to the consist.
    ///
    /// See also `resetFlags`
    /// - Parameter add: NodeID of locomotive node to add
    public func addLocoToConsist(add : NodeID) {
        // consist additional loco to current selection
        var message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x01, 0x0]+add.toArray())
        linkLayer.sendMessage(message)
        
        // consist current selection to additional loco
        message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: add, data: [0x30, 0x01, 0x0]+forLoco.toArray())
        linkLayer.sendMessage(message)

        // reload the consist info from the top after a short delay
        let deadlineTime = DispatchTime.now() + .milliseconds(500)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            self.fetchConsist()
        }
    }
    
    /// Removes one locomotive from the consist.
    /// - Parameter remove: NodeID of locomotive node to remove
    public func removeLocoFromConsist(remove : NodeID) {
        // remove indicated loco from current selection
        var message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x02, 0x00]+remove.toArray())
        linkLayer.sendMessage(message)

        // remove current selection from indicated loco
        message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: remove, data: [0x30, 0x02, 0x00]+forLoco.toArray())
        linkLayer.sendMessage(message)

        // remove from our view of the consist
        for index in 0..<consist.count {
            let entry = consist[index]
            if entry.childLoco == remove {
                consist.remove(at: index)
                break
            }
        }
    }
    
    /// Set the flags in a specific locomotive to known values.
    ///
    /// Note: this adds the locomotive to current consist if not present, but only in the A->B direction. That's not great.
    /// - Parameters:
    ///   - on: NodeID of a locomotive within the current consist
    public func resetFlags(on : NodeID, reverse : Bool, echoF0: Bool, echoFn: Bool, hide: Bool) {
        var byte : UInt8 = 0
        if reverse  { byte |= 0x02 }
        if echoF0   { byte |= 0x04 }
        if echoFn   { byte |= 0x08 }
        if hide     { byte |= 0x80 }

        let message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x01, byte]+on.toArray())
        linkLayer.sendMessage(message)
    }
    
    /// Consist-specific message processor
    /// - Parameters:
    ///   - message: Incoming message
    ///   - node: Which node to process messages for, i.e. each individual node holds it's own processing state
    /// - Returns: Always false: These message don't prompt a global update
    public func process( _ message : Message, _ node : Node ) -> Bool {
        guard checkDestID(message, linkLayer.localNodeID) else { return false }  // not for us?
        guard message.mti == .Traction_Control_Reply else { return false }
        
        // decode type of message
        if message.data[0] == 0x30 {
            // Listener Configuration reply
            if message.data[1] == 0x03 {
                // Listener Configuration Query Node reply, check state
                switch (fetchConsistState) {
                case .AwaitingReadReply :
                    // data[2] = node count
                    // data[3] = node index
                    // data[4] = flags
                    // data[5-10] = node ID
                    //
                    // check for real content
                    if message.data.count >= 9 {
                        // this is a successful read
                        // store the information in a new entry
                        let entry = ConsistEntryModel(childLoco: NodeID(Array(message.data[5...10])))
                        let byte4 = message.data[4]
                        entry.reverse = byte4 & 0x02 != 0
                        entry.echoF0  = byte4 & 0x04 != 0
                        entry.echoFn  = byte4 & 0x08 != 0
                        entry.hide    = byte4 & 0x80 != 0
                        consist.append(entry)
                        // Send next message
                        let nextmsg = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x03, message.data[3]+1]) // to head of consist
                        linkLayer.sendMessage(nextmsg)
                    } else {
                        // empty read reply, we're done
                        // Nullify the state machine
                        fetchConsistState = .Idle
                    }
                    return false
                default:
                    ConsistModel.logger.error("Received \(message, privacy: .public) in unexpected state \(String(describing: self.fetchConsistState), privacy:.public)")
                    return false
                }
                // guard checkSourceID(message, forLoco) else { return false }  // not from top loco?
            }
        }
        return false // not an interesting message for us
    }
}
