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
    
    public var nodes: [Node]
    public var byIdMap: [NodeID : Node]
    public var processors: [Processor]
    
    // local variables
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "RemoteNodeStore")
    
    let localNodeID : NodeID

    init(localNodeID : NodeID) {
        self.nodes  = []
        self.byIdMap = [:]
        self.processors = []
        self.localNodeID = localNodeID
    }

    public var description : String { "RemoteNodeStore w \(nodes.count)"}

    /// Retrieve a Node's content from the store
    /// - Parameter nodeID: Look-up key
    /// - Returns: Returns Node, creating if need be
    // mutates to create non-existing node
    mutating func lookup(_ nodeID : NodeID) -> Node? {
        return byIdMap[nodeID]
    }

    /// Process a message across all nodes
    /// First reception of a message-level transmission, i.e. VerfiedNode, will create an entry for that node
    mutating func invokeProcessorsOnNodes(message : Message) {
        // make sure source node is in store if it needs to be
        if let _ = lookup(message.source) {
            // logger.trace("found node")
        }
        else {
            // need to create the node and process it's New_Node_Seen
            // return nil if in localNodeStore
            let nodeID = message.source
            if nodeID == localNodeID {
                // present in other store, skip
                return
            } else {
                // not present, create
                let node = Node(nodeID)
                logger.debug("creating node \(nodeID, privacy: .public)")
                // NodeID(0) is a special case, used for e.g. linkUp, linkDown; don't store
                if (nodeID != NodeID(0)) {
                    store(node)
                    // TODO: send New_Node_seen before sending message to process - how to make sure all process it
                    let newNodeMessage = Message(mti: MTI.New_Node_Seen, source: nodeID)
                    for processor in processors {
                            processor.process(newNodeMessage, node)
                    }
                } else {
                    logger.debug("  Skipping store of NodeID(0)")
                }
            }
        }
        
        // The following is super.invokeProcessorsOnNodes(message: message)
        for processor in processors {
            for node in byIdMap.values {
                processor.process(message, node)
            }
        }
    }


}
