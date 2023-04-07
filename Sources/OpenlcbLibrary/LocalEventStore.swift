//
//  LocalEventStore.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

/// Store node-specific Event information
///
///  See also ``GlobalEventStore``
///
///  Serves as a View model for displaying the events used by a node
final public class LocalEventStore {
    // TODO: Add support for ranges

    @Published public var eventsConsumed : Set<EventID> = []
    @Published public var eventsProduced : Set<EventID> = []

    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "LocalEventStore")

    func consumes(_ id : EventID) {
        eventsConsumed.insert(id)
    }
    
    func isConsumed(_ id: EventID) -> (Bool) {
        return eventsConsumed.contains(id)
    }
    
    func produces(_ id : EventID) {
        eventsProduced.insert(id)
    }
    
    func isProduced(_ id: EventID) -> (Bool) {
        return eventsProduced.contains(id)
    }
}
