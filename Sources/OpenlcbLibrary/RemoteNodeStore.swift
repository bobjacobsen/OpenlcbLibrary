//
//  RemoteNodeStore.swift
//  
//
//  Created by Bob Jacobsen on 6/10/22.
//

import Foundation
import os

/// Accumulates Nodes that it sees requested, unless they're already in a given local NodeStore
/// 
public struct RemoteNodeStore : NodeStore, CustomStringConvertible {
    
    // variables from NodeStore protocol
    
    // TODO: This should be @Published, but that can only be done on a class.  Needed so that the node navigation list will update when a node's SNIP updates.
    public var nodes: [Node]
    
    public var byIdMap: [NodeID : Node]
    public var processors: [Processor]
    
    // local variables
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "RemoteNodeStore")
    
    // ID of node that's in the local node store instead of here
    let localNodeID : NodeID

    init(localNodeID : NodeID) {
        self.nodes  = []
        self.byIdMap = [:]
        self.processors = []
        self.localNodeID = localNodeID
    }

    public var description : String { "RemoteNodeStore w \(nodes.count)"}

    // return true if the message is to a new node, so that createNewRemoteNode should be called.
    func checkForNewNode(message : Message) -> Bool {
        // return nil if in localNodeStore
        let nodeID = message.source
        if nodeID == localNodeID {
            // present in other store, skip
            return false
        }
        // NodeID(0) is a special case, used for e.g. linkUp, linkDown; don't store
        if (nodeID == NodeID(0)) {
            return false
        }
        // make sure source node is in store if it needs to be
        if let _ = lookup(message.source) {
            return false
        }
        return true
    }
    
    // a new node was found by checkForNewNode, so this
    // mutates the store to add this.  This should only be called
    // if checkForNewNode is true to avoid excess publishing!
    mutating func createNewRemoteNode(message : Message) {
        // need to create the node and process it's New_Node_Seen
        let nodeID = message.source
        let node = Node(nodeID)
        logger.debug("creating node \(nodeID, privacy: .public)")
        
        store(node)
        // All nodes process a notification that there's a new node
        let newNodeMessage = Message(mti: MTI.New_Node_Seen, source: nodeID)
        for processor in processors {
            _ = processor.process(newNodeMessage, node)
        }
    }
    
}
