//
//  LocalNodeStore.swift
//  
//
//  Created by Bob Jacobsen on 7/18/22.
//

import Foundation

struct LocalNodeStore : NodeStore {
    
    // variables required by NodeStore protocol
    var nodes: [Node]
    
    var byIdMap: [NodeID : Node]
    
    var processors: [Processor]
    
    // local members
    public init() {
        self.nodes  = []
        self.byIdMap = [:]
        self.processors = []
    }

}
