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
public class RemoteNodeStore : NodeStore {
    let logger = Logger(subsystem: "com.ardenwood", category: "RemoteNodeStore")
    
    let localNodeStore : NodeStore

    init(localNodeStore : NodeStore) {
        self.localNodeStore = localNodeStore
    }

    /// Retrieve a Node's content from the store
    /// - Parameter nodeID: Look-up key
    /// - Returns: Returns Node, creating if need be
    // mutates to create non-existing node
    override func lookup(_ nodeID : NodeID) -> Node? {
        if let node = byIdMap[nodeID] {
            return node
        } else {
            // doesn't exist; return if not in localNodeStore
            if nil != localNodeStore.lookup(nodeID) {
                // present in other store
                return nil
            } else {
                // not present, create
                let node = Node(nodeID)
                logger.debug("creating node \(nodeID, privacy: .public)")
                // NodeID(0) is a special case, used for e.g. linkUp, linkDown; don't store
                if (nodeID != NodeID(0)) {
                    store(node)
                } else {
                    logger.debug("  Skipping store of NodeID(0)")
                }
                return node
            }            
        }
    }

    /// Process a message across all nodes
    override func invokeProcessorsOnNodes(message : Message) {
        // make sure source node is in store if it needs to be
        _ = lookup(message.source)
        super.invokeProcessorsOnNodes(message: message)
    }


}
