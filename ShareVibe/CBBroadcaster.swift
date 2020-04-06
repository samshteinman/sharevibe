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
    @Published var BytesSentOfCurrentSegmentSoFar: Int = 0
    @Published var TotalBytesOfCurrentSegment: Int = 0
    
    @Published var ListeningCentrals : [CBCentral] = []
    
    @Published var Status : String = ""
    
    @Published var startedPlayingAudio = false
    
    @Published var NumberOfListeners = 0
    @Published var RoomName : String = ""
    
    var songData : Data = Data()
    var needBroadcastSegmentLength = true
    
    var peripheralManager: CBPeripheralManager!
        
    func startStation(roomName : String)
    {
        if peripheralManager == nil
        {
            RoomName = roomName
            
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
    }
    
    func reset()
    {
        Globals.Playback.RestartPlayer()
        
        self.needBroadcastSegmentLength = true
        self.BytesSentOfCurrentSegmentSoFar = 0
        self.startedPlayingAudio = false
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid == Globals.BluetoothGlobals.SongDataUUID
        {
            if let index = self.ListeningCentrals.firstIndex(of: central)
            {
                self.ListeningCentrals.remove(at: index)
                NSLog("Broadcasting listener count \(self.ListeningCentrals.count)")
                peripheral.updateValue(Globals.convertToData(number: self.ListeningCentrals.count), for: Globals.BluetoothGlobals.NumberOfListenersCharacteristic, onSubscribedCentrals: nil)
            }
        }
    }
    
    func trySend(data: Data)
    {
        self.songData = data
        
        if self.ListeningCentrals.count != 0
        {
            trySend()
        }
        
    }
    
    func trySend()
    {
        reset()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        tryBroadcastSegmentLength()
        
        sendWholeSegment()
    }
    
    func sendWholeSegment()
    {
        while(self.BytesSentOfCurrentSegmentSoFar < self.songData.count)
        {
            if let chunk = GetChunkFromCurrentSegment()
            {
                if(peripheralManager.updateValue(chunk, for: Globals.BluetoothGlobals.SegmentDataCharacteristic, onSubscribedCentrals: nil))
                {
                    self.BytesSentOfCurrentSegmentSoFar += chunk.count
                    if(!self.startedPlayingAudio && self.BytesSentOfCurrentSegmentSoFar > Globals.Playback.AmountOfBytesBeforeAudioCanStart)
                    {
                        self.startedPlayingAudio = true
                        Globals.Playback.Player = AVPlayer.init(url: Globals.Playback.ExportedAudioFilePath)
                        Globals.Playback.Player.play()
                    }
                }
                else
                {
                    break
                }
            }
        }
    }
    
    func tryBroadcastSegmentLength()
    {
        if(self.needBroadcastSegmentLength)
        {
            self.TotalBytesOfCurrentSegment = self.songData.count
            
            self.needBroadcastSegmentLength = !peripheralManager.updateValue(Globals.convertToData(number: self.songData.count), for: Globals.BluetoothGlobals.SegmentLengthCharacteristic, onSubscribedCentrals: nil)
            
            if(!self.needBroadcastSegmentLength)
            {
                NSLog("Broadcasted file segment length \(self.TotalBytesOfCurrentSegment)")
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
        self.BytesSentOfCurrentSegmentSoFar = 0
        self.needBroadcastSegmentLength = true
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if self.ListeningCentrals.count != 0
        {
            continueSending()
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        if(characteristic.uuid == Globals.BluetoothGlobals.SongDataUUID)
        {
            NSLog("Updating file data chunk maximum size to \(central.maximumUpdateValueLength)")
            Globals.ChunkSize = Int(central.maximumUpdateValueLength)
            
            if !self.ListeningCentrals.contains(central)
            {
                self.ListeningCentrals.append(central)
                NSLog("Broadcasting listener count \(self.ListeningCentrals.count)")
                peripheral.updateValue(Globals.convertToData(number: self.ListeningCentrals.count), for: Globals.BluetoothGlobals.NumberOfListenersCharacteristic, onSubscribedCentrals: nil)
                
                if(self.ListeningCentrals.count == 1 && self.songData.count > 0)
                {
                    trySend()
                }
            }
        }
        
        NSLog("\(central) subscribed to characteristic \(characteristic.uuid) and can handle: \(central.maximumUpdateValueLength)")
        if(characteristic.uuid == Globals.BluetoothGlobals.SongDataUUID)
        {
            NSLog("Updating file data chunk maximum size to \(central.maximumUpdateValueLength)")
            Globals.ChunkSize = Int(central.maximumUpdateValueLength)
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if(peripheral.state == .poweredOn)
        {
            NSLog("Ready to advertise")
            
            Globals.BluetoothGlobals.Service.characteristics = [Globals.BluetoothGlobals.SegmentLengthCharacteristic, Globals.BluetoothGlobals.SegmentDataCharacteristic,
                                                                Globals.BluetoothGlobals.SongDescriptionCharacteristic,
                                                                Globals.BluetoothGlobals.NumberOfListenersCharacteristic,
                                                                Globals.BluetoothGlobals.RoomNameCharacteristic]
            
            peripheralManager.add(Globals.BluetoothGlobals.Service)
            
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : Globals.BluetoothGlobals.ServiceUUID])
        }
    }
    
    func GetChunkFromCurrentSegment() -> Data?
    {
        if(BytesSentOfCurrentSegmentSoFar >= self.songData.count)
        {
            UIApplication.shared.isIdleTimerDisabled = false
            return nil
        }
        else if(BytesSentOfCurrentSegmentSoFar + Globals.ChunkSize > self.songData.count)
        {
            return self.songData.subdata(in: Data.Index(BytesSentOfCurrentSegmentSoFar)..<(self.songData.count))
        }
        else
        {
            return self.songData.subdata(in: Data.Index(BytesSentOfCurrentSegmentSoFar)..<(Data.Index(BytesSentOfCurrentSegmentSoFar)+Data.Index(Globals.ChunkSize)))
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == Globals.BluetoothGlobals.RoomNameUUID
        {
            request.value = RoomName.data(using: .utf8)
            peripheral.respond(to: request, withResult: .success)
        }
        else if request.characteristic.uuid == Globals.BluetoothGlobals.NumberOfListenersUUID
        {
            request.value = Globals.convertToData(number: self.ListeningCentrals.count)
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
