//
//  Event.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Central organizing point for information associated with a specific Event
///  This is a class, not a struct, because an instance corresponds to an external object (the actual Event), so
///  there's no semantic meaning to making multiple copies.
///
///
public class Event : Equatable, Hashable, CustomStringConvertible {
    let eventID : EventID  // eventID is immutable
    
    public init( _ eventID : EventID) {
        self.eventID = eventID
    }
    
    public var description : String { "Event (\(eventID))"}
    
    // MARK: - protocols
    
    /// Equality is defined on the NodeID only.
    public static func ==(lhs : Event, rhs : Event) -> Bool {
        return lhs.eventID == rhs.eventID
    }
    public func hash(into hasher : inout Hasher) {
        hasher.combine(eventID)
    }
}
