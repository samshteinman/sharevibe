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
import MediaPlayer

public class Globals : NSObject
{
    public class BluetoothGlobals
    {
        static let CurrentFileSegmentDataUUID = CBUUID(string: "78753A44-4D6F-1226-9C60-0050E4C00067")
        static let SongDescriptionUUID = CBUUID(string: "12353A44-4D6F-1226-9C60-0050E4C00067")
        static let CurrentFileSegmentLengthUUID = CBUUID(string: "18753A44-4D6F-1226-9C60-0050E4C00067")
        static let ServiceUUID = CBUUID(string: "88753A44-4D6F-1226-9C60-0050E4C00067")
    }
    
    public class Playback
    {
        static var Player : AVPlayer = AVPlayer.init()
        
        static var StartPlayBytes : UInt64 = 65535
        
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
        
        static func setupRemoteControls()
           {
                   // Get the shared MPRemoteCommandCenter
                   let commandCenter = MPRemoteCommandCenter.shared()

                   // Add handler for Play Command
                   commandCenter.playCommand.addTarget { event in
                       if Globals.Playback.Player.rate == 0.0 {
                           Globals.Playback.Player.play()
                           return .success
                       }
                       return .commandFailed
                   }

                   // Add handler for Pause Command
                   commandCenter.pauseCommand.addTarget { event in
                       if Globals.Playback.Player.rate == 1.0 {
                          Globals.Playback.Player.pause()
                           return .success
                       }
                       return .commandFailed
                   }
           }
         
        static func ConvertUInt32ToData(length : UInt32) -> Data
        {
            var tempHolder = length
            return Data.init(bytes: &tempHolder, count: MemoryLayout.size(ofValue: tempHolder))
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
