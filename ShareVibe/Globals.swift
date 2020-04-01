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
        
        static var StreamingAsset : AVURLAsset!
        static var StreamingPlayerItem : AVPlayerItem!
        
        static var ReceivedAudioFilePath = URL(fileURLWithPath: NSTemporaryDirectory().appending("received" + Playback.AudioFileExtension))
           
        static var ExportedAudioFilePath = URL(fileURLWithPath: NSTemporaryDirectory().appending("exported" + Playback.AudioFileExtension))
        
        
        static func RestartPlayer()
        {
            Globals.Playback.Player.currentItem?.cancelPendingSeeks()
            Globals.Playback.Player.cancelPendingPrerolls()
            Globals.Playback.Player.replaceCurrentItem(with: nil)
            Globals.Playback.Player.pause()
        }
        
        static func ConvertUInt32ToData(length : UInt32) -> Data
        {
            var tempHolder = length
            return Data.init(bytes: &tempHolder, count: MemoryLayout.size(ofValue: tempHolder))
        }
        
        static func getmdatIndex(data: Data) -> UInt64?
        {
            for index in 0..<(data.count - 3)
            {
               if(data[index] == 0x6D
                   && data[index+1] == 0x64
                   && data[index+2] == 0x61
                   && data[index+3] == 0x74)
               {
                return UInt64(index)
               }
            }
            
            return nil
        }
        
        static func getmoovIndex(data: Data) -> UInt64?
               {
                   for index in 0..<(data.count - 3)
                   {
                      if(data[index] == 0x6D
                          && data[index+1] == 0x6F
                          && data[index+2] == 0x6F
                          && data[index+3] == 0x76)
                      {
                       return UInt64(index)
                      }
                   }
                   
                   return nil
               }
    }
    
    static var SharedAudioSession : AVAudioSession!
    
    static var Compress = false
    
    static var ChunkSize = 256
    
    enum Transmissions
    {
       case update, requestRead, L2CAP
    }
    
    static var Transmission = Transmissions.update

    static var ReceivedAudioFilePath = URL(fileURLWithPath: NSTemporaryDirectory().appending("received" + Playback.AudioFileExtension))
          
    static var ExportedAudioFilePath = URL(fileURLWithPath: NSTemporaryDirectory().appending("exported" + Playback.AudioFileExtension))

}
