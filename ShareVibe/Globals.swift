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
    
    public static func convertToData(number : Int) -> Data
    {
        var length = number
        return Data.init(bytes: &length, count: MemoryLayout.size(ofValue: length))
    }
    
    public class BluetoothGlobals
    {
        static let ServiceUUID = CBUUID(string: "88753A44-4D6F-1226-9C60-0050E4C00067")
        
        static let SongDataUUID = CBUUID(string: "78753A44-4D6F-1226-9C60-0050E4C00067")
        static let SongDescriptionUUID = CBUUID(string: "12353A44-4D6F-1226-9C60-0050E4C00067")
        static let NumberOfListenersUUID = CBUUID(string: "55553A44-4D6F-1226-9C60-0050E4C00067")
        static let RoomNameUUID = CBUUID(string: "99953A44-4D6F-1226-9C60-0050E4C00067")
        static let SongLengthUUID = CBUUID(string: "18753A44-4D6F-1226-9C60-0050E4C00067")
        
        static var Service = CBMutableService(type: Globals.BluetoothGlobals.ServiceUUID, primary: true)
        static var CharacteristicProperties: CBCharacteristicProperties = [.notify, .read, .write]
        static var Permissions: CBAttributePermissions = [.readable, .writeable]
        
        static var SegmentLengthCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.SongLengthUUID, properties: Globals.BluetoothGlobals.CharacteristicProperties, value: nil, permissions: Permissions)
        static var SegmentDataCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.SongDataUUID, properties: Globals.BluetoothGlobals.CharacteristicProperties, value: nil, permissions: Permissions)
        static var SongDescriptionCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.SongDescriptionUUID, properties: Globals.BluetoothGlobals.CharacteristicProperties, value: nil, permissions: Permissions)
        static var RoomNameCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.RoomNameUUID, properties: Globals.BluetoothGlobals.CharacteristicProperties, value: nil, permissions: Permissions)
        static var NumberOfListenersCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.NumberOfListenersUUID, properties: Globals.BluetoothGlobals.CharacteristicProperties, value: nil, permissions: Permissions)
        
    }
    
    public class Playback
    {
        public class Status
        {
            static let connecting = "Connecting"
            static let scanningForStations = "Searching for stations"
            static let noSongCurrentlyPlaying = "No song currently playing"
            static let waitingForCurrentSongToFinish = "Waiting for song to finish"
            static let syncingSong = "Syncing, please don't leave"
            static let couldNotStartBluetooth = "Could not start Bluetooth! Please restart the app"
            static let waitingForListeners = "Waiting for listeners"
            static let failedBluetooth = "Bluetooth error! Please check your settings and restart"
            static let preparingSong = "Preparing song"
            static let broadcastingFailed = "Broadcast failed"
            static let failedToShareSong = "Could not share song. Is the song downloaded from the cloud?"
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
        
        static func RestartPlayer()
        {
            Globals.Playback.Player.currentItem?.cancelPendingSeeks()
            Globals.Playback.Player.cancelPendingPrerolls()
            Globals.Playback.Player.replaceCurrentItem(with: nil)
            Globals.Playback.Player.pause()
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
