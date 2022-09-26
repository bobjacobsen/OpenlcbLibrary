//
//  FdiModel.swift
//  
//
//  Created by Bob Jacobsen on 9/25/22.
//

import Foundation
import os

public class FdiModel : XmlModel, ObservableObject {
    
    @Published public var tree : [FdiXmlMemo] = [] // content!

    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "FdiModel")
    
    public init (mservice : MemoryService, nodeID : NodeID ) {
        super.init(mservice: mservice, nodeID: nodeID, space: 0xFA)
    }
    
    override internal func processAquiredText() {
        // actually process it into an XML tree
        tree = FdiXmlMemo.process(savedDataString.data(using: .utf8)!)[0].children! // index due to null base node
    }
    
}
