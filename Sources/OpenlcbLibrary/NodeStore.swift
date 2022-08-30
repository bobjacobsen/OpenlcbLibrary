//
//  NodeStore.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

// TODO: Should this also distribute locally-sent information to all the other nodes?  Local and/or remote node stores?

/// Store the available Nodes and provide multiple means of retrieval.
///  Storage and indexing methods are an internal detail.
///  You can't remove a node; once we know about it, we know about it.
public protocol NodeStore { // for SwiftUI
    
    var nodes : [Node] {get set}
    var byIdMap : [NodeID : Node] {get set}
    var processors : [Processor] {get set}
}

extension NodeStore {
        
    /// Store a new node or replace an existing stored node
    /// - Parameter node: new Node content
    mutating func store(_ node : Node) {
        byIdMap[node.id] = node
        nodes.append(node)
        // nodes.sort() // TODO: Would be nice to sort these in node name order, if there is a node name yet, instead of just by ID
        nodes.sort { $0.snip.userProvidedNodeName < $1.snip.userProvidedNodeName } // TODO: Seems ineffective, done too soon before SNIP arrives?
        // TODO: Do these sorts even do anything? Or are we seeing just arrival order? How can that be? Maybe value semantics and this is passed too early?
    }
    
    /// Retrieve a Node's content from the store
    /// - Parameter nodeID: Look-up key
    /// - Returns: Returns Node, creating if need be
    // Some implementations may mutate to create non-existing node
    func lookup(_ nodeID : NodeID) -> Node? {
        return byIdMap[nodeID]
    }

    func isPresent(_ nodeID : NodeID) -> (Bool) {
        return byIdMap[nodeID] != nil
    }
    
    public func asArray() -> [Node] {
        return Array(byIdMap.values)
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
    
    /// Process a message across all nodes
    mutating func invokeProcessorsOnNodes(message : Message) {
        for processor in processors {
            for node in byIdMap.values {
                processor.process(message, node)
            }
        }
    }
} // end extension to NodeStore
