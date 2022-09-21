//
//  ConsistModel.swift
//  OpenlcbLibrary
//
//  Created by Bob Jacobsen on 8/1/22.
//

import Foundation
import os

final public class ConsistModel : ObservableObject, Processor {
    
    @Published public var forLoco : NodeID = NodeID(0)
    @Published public var consist : [ConsistEntryModel] = []
    
    let linkLayer : LinkLayer
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "ConsistModel")

    public init(linkLayer : LinkLayer) {
        self.linkLayer = linkLayer
    }
    
    // represent a single slement of the consist
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

    // Kick off the process of reading in a single-level, single-link consist
    // starting with the head loco
    //
    // This does direct Query Node operations until a null is returned,
    // without first getting the count.
    public func fetchConsist() {
        // clear the existing model
        consist = []
        // Kick off the read with the first one
        fetchConsistState = .AwaitingReadReply
        let message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x03, 0x00]) // to head of consist
        linkLayer.sendMessage(message)
        // now it heads over to the consist processor to wait for the reply
    }
    
    // add a loco to the consist.  // See also `resetFlags`, which seems to do the same thing sort-of
    public func addLocoToConsist(add : NodeID) {
        let message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x01, 0x0]+add.toArray())
        linkLayer.sendMessage(message)
        // reload the consist info from the top after a short delay
        let deadlineTime = DispatchTime.now() + .milliseconds(500)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            self.fetchConsist()
        }
    }
    
    public func removeLocoFromConsist(remove : NodeID) {
        let message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x02, 0x00]+remove.toArray())
        linkLayer.sendMessage(message)
        // remove from our view of the consist
        for index in 0...consist.count {
            let entry = consist[index]
            if entry.childLoco == remove {
                consist.remove(at: index)
                break
            }
        }
    }
    
    public func resetFlags(on : NodeID, reverse : Bool, echoF0: Bool, echoFn: Bool) {
        var byte : UInt8 = 0
        if reverse  { byte |= 0x02 }
        if echoF0   { byte |= 0x04 }
        if echoFn   { byte |= 0x08 }
        
        let message = Message(mti: .Traction_Control_Command, source: linkLayer.localNodeID, destination: forLoco, data: [0x30, 0x01, byte]+on.toArray())
        linkLayer.sendMessage(message)
    }
    
    // Consist processor
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
                        entry.reverse = message.data[4] & 0x2 != 0
                        entry.echoF0  = message.data[4] & 0x4 != 0
                        entry.echoFn  = message.data[4] & 0x8 != 0
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
