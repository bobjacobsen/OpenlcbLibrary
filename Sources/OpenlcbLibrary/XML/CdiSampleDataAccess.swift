//
//  CdiSampleDataAccess.swift
//  
//
//  Created by Bob Jacobsen on 6/29/22.
//

/// Methods to process access to sample data.  Used for testing, but kept in main
///  file tree so that it can provide sample data to users of the library as example screens, etc.

import Foundation
import os

public struct CdiSampleDataAccess {
    // holds no common data, this is really a collection of methods
    
    static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "CdiSampleDataAccess")
    
    // for testing and sample data
    // reads from ~/Documents and creates an Data element from the file contents
    public static func getDataFromFile(_ file : String) -> Data? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("problem with directory")
            return nil
        }
        do {
            let fileURL = dir.appendingPathComponent(file)
            let data = try Data(contentsOf: fileURL)
            return data
        } catch {
            logger.error("caught \(error, privacy:.public)")
            return nil
        }
    }

    public static func getDataFromBundleFile(_ file : String) -> Data? { // file is without extension, assumed .xml
        let filePath = Bundle.main.path(forResource: file, ofType: "xml");
        let URL = NSURL.fileURL(withPath: filePath!)

        do {
            let string = try String.init(contentsOf: URL)
            let data = string.data(using: .utf8)!
            return data
        } catch  {
            logger.error("caught \(error, privacy:.public)")
        }
        return nil
    }
    
    /// Provide sample CDI as a ``CdiXmlMemo`` tree. Contains
    ///   - a clean sample segement
    ///   - the first segments of an RR-CirKits Tower LCC CDI
    ///
    public static func sampleCdiXmlData() -> [CdiXmlMemo] {
        let data : Data = ("""
                        <cdi>
                        <segment><name>Sample Segment</name><description>Desc of Segment</description>
                            <group><name>Sample Group</name><description>Desc of Group</description>
                            <int><name>Numeric Int</name><description>Description of Num Int</description><default>321</default></int>
                            <int><name>Mapped Int</name><description>Description of Map Int</description><default>2</default>
                                <map>
                                    <relation><property>1</property><value>One</value></relation>
                                    <relation><property>2</property><value>Two</value></relation>
                                    <relation><property>3</property><value>Three</value></relation>
                                </map></int>
                            </group>
                        </segment>
                        
                        <segment space="253" origin="7744">
                          <name>Node Power Monitor</name>
                          <int size="1">
                            <name>Message Options</name>
                            <map>
                              <relation>
                                <property>0</property>
                                <value>None</value>
                              </relation>
                              <relation>
                                <property>1</property>
                                <value>Send Power OK only</value>
                              </relation>
                              <relation>
                                <property>2</property>
                                <value>Send both Power OK and Power Not OK</value>
                              </relation>
                            </map>
                          </int>
                          <eventid>
                            <name>Power OK</name>
                            <description>EventID</description>
                          </eventid>
                          <eventid>
                            <name>Power Not OK</name>
                            <description>EventID (may be lost)</description>
                          </eventid>
                        </segment>
                        <segment space="253" origin="128">
                          <name>Port I/O</name>
                          <group replication="16">
                            <name>Line</name>
                            <description>Select Input/Output line.</description>
                            <repname>Line</repname>
                            <string size="32">
                              <name>Line Description</name>
                            </string>
                            <int size="1" offset="11424">
                              <name>Output Function</name>
                              <map>
                                <relation>
                                  <property>0</property>
                                  <value>None</value>
                                </relation>
                                <relation>
                                  <property>1</property>
                                  <value>Steady</value>
                                </relation>
                                <relation>
                                  <property>2</property>
                                  <value>Pulse</value>
                                </relation>
                                <relation>
                                  <property>3</property>
                                  <value>Blink A</value>
                                </relation>
                                <relation>
                                  <property>4</property>
                                  <value>Blink B</value>
                                </relation>
                              </map>
                            </int>
                            <int size="1">
                              <name>Receiving the configured Command (C) event(s) will drive or pulse the line:</name>
                              <map>
                                <relation>
                                  <property>0</property>
                                  <value>Low  (0V)</value>
                                </relation>
                                <relation>
                                  <property>1</property>
                                  <value>High (5V)</value>
                                </relation>
                              </map>
                            </int>
                            <int size="1">
                              <name>Input Function</name>
                              <map>
                                <relation>
                                  <property>0</property>
                                  <value>None</value>
                                </relation>
                                <relation>
                                  <property>1</property>
                                  <value>Normal</value>
                                </relation>
                                <relation>
                                  <property>2</property>
                                  <value>Alternating</value>
                                </relation>
                              </map>
                            </int>
                            <int size="1">
                              <name>The configured Indication (P) event(s) will be sent when the line is driven:</name>
                              <map>
                                <relation>
                                  <property>0</property>
                                  <value>Low  (0V)</value>
                                </relation>
                                <relation>
                                  <property>1</property>
                                  <value>High (5V)</value>
                                </relation>
                              </map>
                            </int>
                            <group replication="2" offset="-11426">
                              <name>Delay</name>
                              <description>Delay time values for blinks, pulses, debounce.</description>
                              <repname>Interval</repname>
                              <int size="2">
                                <name>Delay Time (1-60000)</name>
                              </int>
                              <int size="1">
                                <name>Units</name>
                                <map>
                                  <relation>
                                    <property>0</property>
                                    <value>Milliseconds</value>
                                  </relation>
                                  <relation>
                                    <property>1</property>
                                    <value>Seconds</value>
                                  </relation>
                                  <relation>
                                    <property>2</property>
                                    <value>Minutes</value>
                                  </relation>
                                </map>
                              </int>
                              <int size="1">
                                <name>Retrigger</name>
                                <map>
                                  <relation>
                                    <property>0</property>
                                    <value>No</value>
                                  </relation>
                                  <relation>
                                    <property>1</property>
                                    <value>Yes</value>
                                  </relation>
                                </map>
                              </int>
                            </group>
                            <group replication="6">
                              <name>Event</name>
                              <repname>Event</repname>
                              <eventid>
                                <name>Command</name>
                                <description>(C) When this event occurs</description>
                              </eventid>
                              <int size="1">
                                <name>Action</name>
                                <description>the line state will be changed to</description>
                                <map>
                                  <relation>
                                    <property>0</property>
                                    <value>None</value>
                                  </relation>
                                  <relation>
                                    <property>1</property>
                                    <value>On  (Line Active)</value>
                                  </relation>
                                  <relation>
                                    <property>2</property>
                                    <value>Off (Line Inactive)</value>
                                  </relation>
                                  <relation>
                                    <property>3</property>
                                    <value>Change (Toggle)</value>
                                  </relation>
                                  <relation>
                                    <property>4</property>
                                    <value>Veto On  (Active)</value>
                                  </relation>
                                  <relation>
                                    <property>5</property>
                                    <value>Veto Off (Inactive)</value>
                                  </relation>
                                  <relation>
                                    <property>6</property>
                                    <value>Gated On  (Non Veto Output)</value>
                                  </relation>
                                  <relation>
                                    <property>7</property>
                                    <value>Gated Off (Non Veto Output)</value>
                                  </relation>
                                  <relation>
                                    <property>8</property>
                                    <value>Gated Change (Non Veto Toggle)</value>
                                  </relation>
                                </map>
                              </int>
                            </group>
                            <group replication="6">
                              <name>Event</name>
                              <repname>Event</repname>
                              <int size="1">
                                <name>Upon this action</name>
                                <map>
                                  <relation>
                                    <property>0</property>
                                    <value>None</value>
                                  </relation>
                                  <relation>
                                    <property>1</property>
                                    <value>Output State On command</value>
                                  </relation>
                                  <relation>
                                    <property>2</property>
                                    <value>Output State Off command</value>
                                  </relation>
                                  <relation>
                                    <property>3</property>
                                    <value>Output On (Function hi)</value>
                                  </relation>
                                  <relation>
                                    <property>4</property>
                                    <value>Output Off (Function lo)</value>
                                  </relation>
                                  <relation>
                                    <property>5</property>
                                    <value>Input On</value>
                                  </relation>
                                  <relation>
                                    <property>6</property>
                                    <value>Input Off</value>
                                  </relation>
                                  <relation>
                                    <property>7</property>
                                    <value>Gated On (Non Veto Input)</value>
                                  </relation>
                                  <relation>
                                    <property>8</property>
                                    <value>Gated Off (Non Veto Input)</value>
                                  </relation>
                                </map>
                              </int>
                              <eventid>
                                <name>Indicator</name>
                                <description>(P) this event will be sent</description>
                              </eventid>
                            </group>
                          </group>
                        </segment>
                        </cdi>
                        """.data(using: .utf8))!

        return CdiXmlMemo.process(data) // return top-level element_s_, which is (by Schema) just one element TOP_LEVEL element

    }

}
