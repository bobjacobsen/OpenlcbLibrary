//
//  ConsistModel.swift
//  OpenlcbLibrary
//
//  Created by Bob Jacobsen on 8/1/22.
//

import Foundation

class ConsistModel {
    
    @Published var forLoco : NodeID
    @Published var consist : [ConsistEntryModel] = []
    
    init(forLoco: NodeID) {
        self.forLoco = forLoco
    }
    
    // represent a single slement of the consist
    class ConsistEntryModel {
        @Published var childLoco : NodeID
        
        @Published var reverse : Bool = false
        @Published var echoF0 : Bool = false
        @Published var echoFn : Bool = false
        @Published var hide : Bool = false
        
        convenience init(childLoco : NodeID) {
            self.init(childLoco : childLoco, reverse : false, echoF0 : false, echoFn : false, hide: false)
        }
        
        init(childLoco : NodeID, reverse : Bool, echoF0 : Bool, echoFn : Bool, hide: Bool) {
            self.childLoco = childLoco
            self.reverse = reverse
            self.echoF0 = echoF0
            self.echoFn = echoFn
            self.hide = hide
        }

    }
}
