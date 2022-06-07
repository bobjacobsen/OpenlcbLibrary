//
//  Node.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Central organizing point for information contained in a physical Node.
///  This is a class, not a struct, because an instance corresponds to an external object (the actual Node), so
///  there's no semantic meaning to making multiple copies.
///
///  Concrete implementations may include a "node in this machine" and a "remote node elsewhere" a.k.a an image node.
///
public class Node : Equatable, Hashable, CustomStringConvertible {
    let nodeID : NodeID  // nodeID is immutable
    
    // TODO: This needs to be a computed property from SNIP
    let name : String
    
    enum State {
        case Uninitialized
        case Initialized
    }
    var state : State = .Uninitialized

    var pipSet = Set<PIP>()
    var snip = SNIP()
    
    public init( _ nodeID : NodeID) {
        self.nodeID = nodeID
        self.name = ""
    }
    
    public var description : String { "Node (\(nodeID))"}
    
    // MARK: - protocols
    
    /// Equality is defined on the NodeID only.
    public static func ==(lhs: Node, rhs:Node) -> Bool {
        return lhs.nodeID == rhs.nodeID
    }
    public func hash(into hasher : inout Hasher) {
        hasher.combine(nodeID)
    }
}

