//
//  Globals.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-03-17.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import Foundation
import AVFoundation
import CoreBluetooth

/*
 Listener or a Station
 
 Listener:
 #1 Listener subscribes to notifications of length and data characteristics
 #2 If receiving SegmentData, but current file length is nil, fetch the file length
 #3 When receiving enough data, add to AVQueuePlayer
 
 
 When a station is playing:
 for every next segment played, update the NowBroadcastingSegment
 
 */

public class Globals : NSObject
{
    enum State
    {
        case listener, station
    }
    
    static var CurrentState : State?
    
    public class BluetoothGlobals
    {
        static let CurrentFileSegmentDataUUID = CBUUID(string: "78753A44-4D6F-1226-9C60-0050E4C00067")
        static let CurrentFileSegmentLengthUUID = CBUUID(string: "18753A44-4D6F-1226-9C60-0050E4C00067")
        static let ServiceUUID = CBUUID(string: "88753A44-4D6F-1226-9C60-0050E4C00067")
    }
    
    public class Playback
    {
        static var Player : AVPlayer = AVPlayer.init()
        
        static let AudioFileExtension = ".mp4"
    }
    
    static var ReceivedAudioFilePath = URL(fileURLWithPath: NSTemporaryDirectory().appending("received" + Playback.AudioFileExtension))
       
    static var ExportedAudioFilePath = URL(fileURLWithPath: NSTemporaryDirectory().appending("exported" + Playback.AudioFileExtension))
    
    static var SharedAudioSession : AVAudioSession!
    
    static var CompressionAlgorithm = NSData.CompressionAlgorithm.lzfse
    
    static var Compress = false
    
    static var ChunkSize : UInt64 = 182
    
    enum Transmissions
    {
       case update, requestRead, L2CAP
    }
    
    static var Transmission = Transmissions.update
}
