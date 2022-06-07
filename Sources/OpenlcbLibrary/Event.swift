//
//  Event.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Central organizing point for information associated with a specific Event
///
//
// This is a struct for efficiency reasons.
//
struct Event : Equatable, Hashable, CustomStringConvertible {
    let eventID : EventID  // eventID is immutable
    
    init( _ eventID : EventID) {
        self.eventID = eventID
    }
    
    var description : String { "Event (\(eventID))"}
    
    // MARK: - protocols
    
    /// Equality is defined on the EventID only.
    static func ==(lhs : Event, rhs : Event) -> Bool {
        return lhs.eventID == rhs.eventID
    }
    /// Hash is defined on the EventID only
    func hash(into hasher : inout Hasher) {
        hasher.combine(eventID)
    }
}
