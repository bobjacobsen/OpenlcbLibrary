//
//  CdiXmlMemo.swift
//  
//
//  Created by Bob Jacobsen on 6/19/22.
//

/// Representation of a CDI XML node
///
import Foundation

// CdiXmlMemo is a class so that reference semantics can be used to parts of the tree of memos
// The tree of CdiMemo objects only has downward links, so no cycles are created (nor allowed)
public final class CdiXmlMemo : Identifiable {
    public enum XMLMemoType { // represent the type of each node
        case TOPLEVEL // cdi element itself
        case SEGMENT  // Segment is a top-level group
        case GROUP
        case GROUP_REP // child of group for replications > 1
        case INPUT_EVENTID
        case INPUT_INT
        case INPUT_STRING
        case MAP        // held within a INPUT_* node
    }
    // common values
    public var type : XMLMemoType
    public var name : String
    public var repname : String
    public var description : String
    // input values - usage determined by type
    public var length : Int
    public var offset : Int                 // initial offset from the CDI
    public var space : Int
    
    public var defaultValue : Int
    public var maxValue = 2_147_483_647     // 32 bit max
    public var minValue = 0
    
    public var startAddress : Int // set on segment element, otherwise computed
    
    public var currentIntValue : Int
    public var currentStringValue : String

    public var children : [CdiXmlMemo]? // Optional required to display in SwiftUI?  Never nil here.
    
    public var properties : [String] = []
    public var values : [String] = []
    
    public let id = UUID() // for Identifiable
    
    // TODO: ACDI expansion
    // TODO: How to handle the identification block?  Present or not? Read-only
    
    /// Copy ctor makes deep copy
    init(_ memo : CdiXmlMemo) {
        self.type = memo.type
        self.name = memo.name
        self.repname = memo.repname
        self.description = memo.description
        self.length = memo.length
        self.offset = memo.offset
        self.space = memo.space
        self.startAddress = memo.startAddress
        self.defaultValue = memo.defaultValue
        self.currentIntValue = memo.currentIntValue
        self.currentStringValue = memo.currentStringValue
        // make a recursive deep copy of memo.children
        self.children = nil
        if let children = memo.children {
            self.children = []
            for child in children {
                self.children!.append(CdiXmlMemo(child))
            }
        }
        self.properties = []
        for property in memo.properties {
            self.properties.append(property)
        }
        self.values = []
        for value in memo.values {
            self.values.append(value)
        }

        
    }
    
    /// Null object ctor - for later fill-out
    init() {
        self.type = .TOPLEVEL
        self.name = ""
        self.repname = ""
        self.description = ""
        self.length = 0
        self.offset = 0
        self.startAddress = 0
        self.space = 0
        self.defaultValue = 0
        self.currentIntValue = 0
        self.currentStringValue = ""
        self.children = []
    }
    
    /// Take a String Data object containing CDI XML and process it into a CdiXmlMemo tree
    ///    Includes post-processing streps
    static public func process(_ data : Data) -> [CdiXmlMemo] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate
        
        // run the parser
        parser.parse()
        // and post-process
        processGroupReplication(delegate.memoStack[0])
        _ = computeMemoryLocations(delegate.memoStack[0], space: 0, endAddress: 0)
        
        return delegate.memoStack
    }
    
    // recurse through the Memo tree to expand group(replication>1) -> multiple GROUP_REP memos in the tree
    static private func processGroupReplication(_ memo : CdiXmlMemo) {
        if memo.type == .GROUP  && memo.length > 1 { // length holds replication count
            // here, replication is required
            // copy the current node to get children, etc,
            let newChildNode = CdiXmlMemo(memo) // includes making a deep copy
            newChildNode.type = .GROUP_REP // this will be the master that's copied for the new childen
            
            // drop children in prior memo
            memo.children = []  // clears old elements (int, event, even group) that are now in new sub-elements
            
            // add repl nodes as children of original
            for i in 1...memo.length {
                let tempChildNode = CdiXmlMemo(newChildNode)  // create a new, to-be child node
                tempChildNode.name = memo.repname+" \(i)"
                memo.children?.append(tempChildNode)
            }
        }
        // done if needed here, descend into children (including the new .GROUP_REP nodes, which are just skipped over)
        if let children = memo.children {
            for child in children {
                processGroupReplication(child)
            }
        }
    }

    // Recursively scan the tree (depth first) assigning starting addresses.
    // Assumes that group expansion has already taken place (or won't be done)
    static private func computeMemoryLocations(_ memo : CdiXmlMemo, space : Int, endAddress : Int) -> Int {  // returns endAddress of entire memo subtree
        var nextSpace = space
        var newEndAddress = endAddress
        
        if memo.type == .SEGMENT {
            nextSpace = memo.space
            newEndAddress = memo.startAddress
        } else {
            memo.startAddress = endAddress+memo.offset
            newEndAddress = memo.startAddress+memo.length
        }
        memo.space = nextSpace
        // descend into children (including the new .GROUP_REP nodes)
        if let children = memo.children {
            for child in children {
                newEndAddress = computeMemoryLocations(child, space: nextSpace, endAddress: newEndAddress)
            }
        }
        return newEndAddress
    }

}


