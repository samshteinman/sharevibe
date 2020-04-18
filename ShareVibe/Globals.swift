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
import SwiftUI

public class Globals : NSObject
{
    enum CBState
    {
        case Broadcaster
        case Listening
    }
    
    static var State : CBState?
    
    public static func convertToData(number : Int) -> Data
    {
        var length = number
        return Data.init(bytes: &length, count: MemoryLayout.size(ofValue: length))
    }
    
    public class Bluetooth
    {
        static let ServiceUUID = CBUUID(string: "80CB4CF2-ED9B-4712-B85B-BE923376283F")
        
        static let SongDataUUID = CBUUID(string: "E0E7E0A1-72E3-48EE-92DD-D0B5C91D76C6")
        static let NumberOfListenersUUID = CBUUID(string: "BE4326EE-58C7-4027-847F-85AF6F78DC5F")
        static let RoomNameUUID = CBUUID(string: "A7540A18-4089-44A3-9798-0DBA59D7DA85")
        static let SongLengthUUID = CBUUID(string: "646B1DE9-2C10-4B0E-92FF-47B34319815F")
        
        static var Service = CBMutableService(type: Globals.Bluetooth.ServiceUUID, primary: true)
        static var CharacteristicProperties: CBCharacteristicProperties = [.notify, .read, .write]
        static var Permissions: CBAttributePermissions = [.readable, .writeable]
        
        static var SegmentLengthCharacteristic = CBMutableCharacteristic(type: Globals.Bluetooth.SongLengthUUID, properties: Globals.Bluetooth.CharacteristicProperties, value: nil, permissions: Permissions)
        static var SegmentDataCharacteristic = CBMutableCharacteristic(type: Globals.Bluetooth.SongDataUUID, properties: Globals.Bluetooth.CharacteristicProperties, value: nil, permissions: Permissions)
        static var RoomNameCharacteristic = CBMutableCharacteristic(type: Globals.Bluetooth.RoomNameUUID, properties: Globals.Bluetooth.CharacteristicProperties, value: nil, permissions: Permissions)
        static var NumberOfListenersCharacteristic = CBMutableCharacteristic(type: Globals.Bluetooth.NumberOfListenersUUID, properties: Globals.Bluetooth.CharacteristicProperties, value: nil, permissions: Permissions)
        
    }
    
    public class Playback
    {
        static func setupRemoteAudioControls()
        {
            let commandCenter = MPRemoteCommandCenter.shared()
            commandCenter.playCommand.addTarget { event in
                if Globals.Playback.Player.rate == 0
                {
                   Globals.Playback.Player.play()
                    return .success
                }
                return .commandFailed
            }
            
            commandCenter.pauseCommand.addTarget { event in
                if Globals.Playback.Player.rate > 0
                {
                   Globals.Playback.Player.pause()
                    return .success
                }
                return .commandFailed
            }
        }
        
        public class Status
        {
            static let settingUp = "Setting up"
            static let connecting = "Connecting"
            static let scanningForStations = "Searching for stations"
            static let noSongCurrentlyPlaying = "No song currently playing"
            static let waitingForCurrentSongToFinish = "Waiting for song to finish"
            static let bufferingSong = "Buffering"
            static let bufferingDontLeaveSong = bufferingSong + ", please don't leave"
            static let waitingForListeners = "Waiting for listeners"
            static let failedBluetooth = "Bluetooth error! Please check your settings and restart"
            static let preparingSong = "Preparing song"
            static let broadcastingFailed = "Broadcast failed! Please check your settings and restart"
            static let failedToShareSong = "Could not share song. Is the song downloaded from the cloud?"
            static let errorPlayingSong = "Failed to play song. Sorry please try again"
            static let pleaseDisconnect = "Please disconnect"
            static let pleaseDisconnectFromStation = "Cannot start broadcast while listening to a station. Please disconnect from station and try again"
            static let pleaseRestart = "Please restart"
            static let broadcastMadePleaseRestart = "Cannot start listening after a station has been made. Please restart the app to start listening"
        }
        
        static var Player : AVPlayer = AVPlayer.init()
        
        static var AmountOfBytesBeforeAudioCanStartListener : Int = 65535
        static var AmountOfBytesBeforeAudioCanStartBroadcaster : Int = 69035
        
        static let AudioFileExtension = ".mp4"
        
        static var ReceivedAudioFilePath = URL(fileURLWithPath: NSTemporaryDirectory().appending("received" + Playback.AudioFileExtension))
        
        static var ExportedAudioFilePath = URL(fileURLWithPath: NSTemporaryDirectory().appending("exported" + Playback.AudioFileExtension))
        
        static var StreamingAsset : AVURLAsset!
        static var StreamingPlayerItem : AVPlayerItem!
        
        static var BytesPlayedSoFar = 0
        
        static func RestartPlayer(mute : Bool)
        {
            Globals.Playback.Player.currentItem?.cancelPendingSeeks()
            Globals.Playback.Player.cancelPendingPrerolls()
            Globals.Playback.Player.replaceCurrentItem(with: nil)
            Globals.Playback.Player.pause()
            Globals.Playback.Player = AVPlayer.init()
            Globals.Playback.Player.isMuted = mute
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
