//
//  NodeStore.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

// TODO: Should this also distribute locally-sent information to all the remote nodes? i.e. a SNIP request to track

/// Store the available Nodes and provide multiple means of retrieval.
///
/// Storage and indexing methods are an internal detail.
/// You can't remove a node; once we know about it, we know about it.
public class NodeStore : ObservableObject { // for SwiftUI
    
    @Published public var nodes : [Node] = []
    
    var byIdMap : [NodeID : Node] = [:]
    var processors : [Processor] = []
        
    /// Store a new node or replace an existing stored node
    /// - Parameter node: new Node content
    func store(_ node : Node) {
        byIdMap[node.id] = node
        nodes.append(node)

        // sort by SNIP user name (ascending, blanks at front)
        nodes.sort { $0.snip.userProvidedNodeName < $1.snip.userProvidedNodeName } // This can be too early, when node created but no SNIP yet, so also sort before use in View
    }
    
    /// Retrieve a Node's content from the store
    /// - Parameter nodeID: Look-up key
    /// - Returns: Returns Node, creating if need be
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
    func invokeProcessorsOnNodes(message : Message) -> Bool {
        var publish = false
        for processor in processors {
            for node in byIdMap.values {
                publish = processor.process(message, node) || publish // always  invoke Processsor on node
            }
        }
        return publish
    }
} // end extension to NodeStore
