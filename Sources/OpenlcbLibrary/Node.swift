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
public class Node : Equatable, Hashable, Comparable, // for Sets and sorts
                    ObservableObject, Identifiable,  // for SwiftUI
                    CustomStringConvertible {        // for pretty printing
    
    public let id : NodeID  // nodeID is immutable; also serves for Identifiable
 
    // This is a computed property from SNIP
    public var name : String {
        return snip.userProvidedNodeName
    }
    
    enum State {
        case Uninitialized
        case Initialized
    }
    var state : State = .Uninitialized

    public var pipSet = Set<PIP>()
    public var snip = SNIP()
    
    public init( _ nodeID : NodeID) {
        self.id = nodeID
    }
    
    // two ctors for use with SwiftUI previews
    public convenience init( _ nodeID : NodeID, pip : Set<PIP> ) {
        self.init(nodeID)
        pipSet = pip
    }
    public convenience init( _ nodeID : NodeID, snip : SNIP ) {
        self.init(nodeID)
        self.snip = snip
    }

    public var description : String { "Node (\(id))"}
    
    // MARK: - protocols
    
    /// Equality is defined on the NodeID only.
    public static func ==(lhs: Node, rhs:Node) -> Bool {
        return lhs.id == rhs.id
    }
    public func hash(into hasher : inout Hasher) {
        hasher.combine(id)
    }
    // Comparable is defined on the ID
    public static func <(lhs: Node, rhs: Node) -> Bool {
        return lhs.id.nodeId < rhs.id.nodeId
    }

}

