//
//  PeripheralCentralManager.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-03-14.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import Foundation
import CoreBluetooth
import MediaPlayer

class CBBroadcaster : NSObject, ObservableObject, CBPeripheralManagerDelegate, MPMediaPickerControllerDelegate
{
    var peripheralManager: CBPeripheralManager!
    
    @Published var StationStarted : Bool = false
    
    @Published var BytesSentOfSoFar: Int = 0
    @Published var ExpectedAmountOfBytes: Int = 0
    
    @Published var ListeningCentrals : [CBCentral] = []
    
    @Published var Status : String = ""
    @Published var HasError : Bool = false
    
    @Published var startedPlayingAudio = false
    @Published var isMuted: Bool = false
    
    @Published var NumberOfListeners = 0
    @Published var RoomName : String = ""
    
    var songData : Data = Data()
    var needBroadcastExpectedBytesLength = true
    
    func startStation(roomName : String)
    {
        if peripheralManager == nil
        {
            RoomName = roomName
            
            Status = Globals.Playback.Status.settingUp
            
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
                        
            Globals.State = Globals.CBState.Broadcaster
        }
    }
    
    func startAdvertising()
    {
        Globals.Bluetooth.Service.characteristics = [Globals.Bluetooth.SegmentLengthCharacteristic, Globals.Bluetooth.SegmentDataCharacteristic,
                                                     Globals.Bluetooth.NumberOfListenersCharacteristic,
                                                     Globals.Bluetooth.RoomNameCharacteristic]
        
        peripheralManager.add(Globals.Bluetooth.Service)
        
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [Globals.Bluetooth.ServiceUUID]])
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if(peripheral.state == .poweredOn)
        {
            NSLog("Ready to advertise")
            
            startAdvertising()
        }
        else
        {
            Status = Globals.Playback.Status.failedBluetooth
            HasError = true
        }
    }
    
    func resetBroadcast()
    {
        Globals.Playback.RestartPlayer(mute: isMuted)
        
        self.needBroadcastExpectedBytesLength = true
        BytesSentOfSoFar = 0
        self.startedPlayingAudio = false
        HasError = false
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid == Globals.Bluetooth.SongDataUUID
        {
            if let index = self.ListeningCentrals.firstIndex(of: central)
            {
                self.ListeningCentrals.remove(at: index)
                NSLog("Broadcasting listener count \(self.ListeningCentrals.count)")
                peripheral.updateValue(Globals.convertToData(number: self.ListeningCentrals.count), for: Globals.Bluetooth.NumberOfListenersCharacteristic, onSubscribedCentrals: nil)
            }
        }
    }
    
    func startBroadcasting(data: Data)
    {
        self.songData = data
        
        if self.ListeningCentrals.count != 0
        {
            trySend()
        }
        else
        {
            Status = Globals.Playback.Status.waitingForListeners
        }
    }
    
    @objc func playerDidFinishPlaying(note: Notification)
    {
        resetBroadcast()
        Status = Globals.Playback.Status.noSongCurrentlyPlaying
    }
    
    func trySend()
    {
        resetBroadcast()
        
        tryBroadcastSegmentLength()
        
        sendWholeSegment()
    }
    
    func sendWholeSegment()
    {
        while(self.BytesSentOfSoFar < self.songData.count)
        {
            let BufferingAudio = self.BytesSentOfSoFar > 0 && self.BytesSentOfSoFar < Globals.Playback.AmountOfBytesBeforeAudioCanStartBroadcaster
            
            UIApplication.shared.isIdleTimerDisabled = BufferingAudio
            
            if(BufferingAudio && Status != Globals.Playback.Status.bufferingDontLeaveSong)
            {
                Status = Globals.Playback.Status.bufferingDontLeaveSong
            }
            
            if let chunk = GetChunkFromCurrentSegment()
            {
                if(peripheralManager.updateValue(chunk, for: Globals.Bluetooth.SegmentDataCharacteristic, onSubscribedCentrals: nil))
                {
                    NSLog("Sent \(chunk.count) bytes")
                    self.BytesSentOfSoFar += chunk.count
                    if(!self.startedPlayingAudio && self.BytesSentOfSoFar > Globals.Playback.AmountOfBytesBeforeAudioCanStartBroadcaster)
                    {
                        self.startedPlayingAudio = true
                        
                        Globals.Playback.Player.replaceCurrentItem(with: AVPlayerItem.init(url: Globals.Playback.ExportedAudioFilePath))
                        Globals.Playback.Player.play()
                    }
                }
                else
                {
                    NSLog("Transmit queue full at \(self.BytesSentOfSoFar) bytes")
                    //TODO: Add a queue, instead of failing on the updatevalue every time
                    break
                }
            }
        }
    }
    
    func tryBroadcastSegmentLength()
    {
        if(self.needBroadcastExpectedBytesLength)
        {
            self.ExpectedAmountOfBytes = self.songData.count
            
            self.needBroadcastExpectedBytesLength = !peripheralManager.updateValue(Globals.convertToData(number: self.songData.count), for: Globals.Bluetooth.SegmentLengthCharacteristic, onSubscribedCentrals: nil)
            
            if(!self.needBroadcastExpectedBytesLength)
            {
                NSLog("Broadcasted file segment length \(self.ExpectedAmountOfBytes)")
            }
        }
    }
    
    func continueSending()
    {
        tryBroadcastSegmentLength()
        sendWholeSegment()
    }
    
    func setupForNextSegment()
    {
        self.BytesSentOfSoFar = 0
        self.needBroadcastExpectedBytesLength = true
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if self.ListeningCentrals.count != 0
        {
            continueSending()
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        if(characteristic.uuid == Globals.Bluetooth.SongDataUUID)
        {
            NSLog("Updating file data chunk maximum size to \(central.maximumUpdateValueLength)")
            Globals.ChunkSize = Int(central.maximumUpdateValueLength)
            
            if !self.ListeningCentrals.contains(central)
            {
                self.ListeningCentrals.append(central)
                NSLog("Broadcasting listener count \(self.ListeningCentrals.count)")
                peripheral.updateValue(Globals.convertToData(number: self.ListeningCentrals.count), for: Globals.Bluetooth.NumberOfListenersCharacteristic, onSubscribedCentrals: nil)
                
                if(self.ListeningCentrals.count == 1 && self.songData.count > 0)
                {
                    trySend()
                }
            }
        }
        
        NSLog("\(central) subscribed to characteristic \(characteristic.uuid) and can handle: \(central.maximumUpdateValueLength)")
        if(characteristic.uuid == Globals.Bluetooth.SongDataUUID)
        {
            NSLog("Updating file data chunk maximum size to \(central.maximumUpdateValueLength)")
            Globals.ChunkSize = Int(central.maximumUpdateValueLength)
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error{
            Status = Globals.Playback.Status.failedBluetooth
            NSLog("\(error)")
            HasError = true
        }
        else
        {
            Status = Globals.Playback.Status.noSongCurrentlyPlaying
            
            StationStarted = true
        }
    }
    
    func GetChunkFromCurrentSegment() -> Data?
    {
        if(BytesSentOfSoFar >= self.songData.count)
        {
            return nil
        }
        else if(BytesSentOfSoFar + Globals.ChunkSize > self.songData.count)
        {
            return self.songData.subdata(in: BytesSentOfSoFar..<self.songData.count)
        }
        else
        {
            return self.songData.subdata(in: BytesSentOfSoFar..<BytesSentOfSoFar+Globals.ChunkSize)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == Globals.Bluetooth.RoomNameUUID
        {
            request.value = RoomName.data(using: .utf8)
            peripheral.respond(to: request, withResult: .success)
        }
        else if request.characteristic.uuid == Globals.Bluetooth.NumberOfListenersUUID
        {
            request.value = Globals.convertToData(number: self.ListeningCentrals.count)
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
