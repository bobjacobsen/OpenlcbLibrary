//
//  NodeStore.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Store the available Nodes and provide multiple means of retrieval.
///  Storage and indexing methods are an internal detail.
///  You can't remove a node; once we know about it, we know about it.
struct NodeStore {
    private var byIdMap : [NodeID : Node] = [:]
    var processors : [Processor] = []
    
    /// Store a new node or replace an existing stored node
    /// - Parameter node: new Node content
    mutating func store(_ node : Node) {
        byIdMap[node.id] = node
    }
    
    /// Retrieve a Node's content from the store
    /// - Parameter nodeID: Look-up key
    /// - Returns: Returns Node, creating if need be
    // mutates to create non-existing node
    mutating func lookup(_ nodeID : NodeID) -> Node {
        if let node = byIdMap[nodeID] {
            return node
        } else {
            let node = Node(nodeID)
            store(node)
            return node
        }
    }

    /// Retrieve a Node's content from the store
    /// - Parameter userProvidedDescription: Look-up key, from SNIP content
    /// - Returns: Optional<Node>, hence nil if Node hasn't been stored
    func lookup(userProvidedDescription : String) -> Node? {
        for (_, node) in byIdMap {
            if (node.snip.userProvidedDescription == userProvidedDescription) {
                return node
            }
        }
        return nil
    }
    
    // TODO:  add invokeProcessors() to loop over processors X nodes
    
    // TODO:  How does a store get updated when a new node is observed? Sometimes that means a new node (remoteStore), sometimes not (localStore)
    
}
