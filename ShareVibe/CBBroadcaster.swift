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
    
    @Published var Centrals : [CBCentral] = []
    
    var songData : Data!
    var needBroadcastSegmentLength = true
    
    var peripheralManager: CBPeripheralManager!
    
    static var Service = CBMutableService(type: Globals.BluetoothGlobals.ServiceUUID, primary: true)
    static var CharacteristicProperties: CBCharacteristicProperties = [.notify, .read, .write]
    static var Permissions: CBAttributePermissions = [.readable, .writeable]
    static var SegmentLengthCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.SongLengthUUID, properties: CharacteristicProperties, value: nil, permissions: Permissions)
    static var SegmentDataCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.SongDataUUID, properties: CharacteristicProperties, value: nil, permissions: Permissions)
    static var SongDescriptionCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.SongDescriptionUUID, properties: CharacteristicProperties, value: nil, permissions: Permissions)
    static var SongControlCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.SongControlUUID, properties: CharacteristicProperties, value: nil, permissions: Permissions)
    
    func startup()
    {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func reset()
    {
        self.needBroadcastSegmentLength = true
        self.BytesSentOfCurrentSegmentSoFar = 0
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if let index = self.Centrals.firstIndex(of: central)
        {
            self.Centrals.remove(at: index)
        }
    }
    
    func trySend(data: Data)
    {
        self.songData = data
        
        reset()
        
        UIApplication.shared.isIdleTimerDisabled = true
                           
        tryBroadcastSegmentLength()
                       
        sendWholeSegment()
        
        //TODO: Listening first then broadcast vs broadcast first then listen
    }
    
    func sendWholeSegment()
    {
        while(self.BytesSentOfCurrentSegmentSoFar < self.songData.count)
        {
            if let chunk = GetChunkFromCurrentSegment()
            {
                if(peripheralManager.updateValue(chunk, for: CBBroadcaster.SegmentDataCharacteristic, onSubscribedCentrals: nil))
                {
                    self.BytesSentOfCurrentSegmentSoFar += chunk.count
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
            
            self.needBroadcastSegmentLength = !peripheralManager.updateValue(getCurrentSegmentLengthAsData() ,for: CBBroadcaster.SegmentLengthCharacteristic, onSubscribedCentrals: nil)
            
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
        if self.Centrals.count != 0
        {
            continueSending()
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        if !self.Centrals.contains(central)
        {
            self.Centrals.append(central)
        }
        
        NSLog("Someone subscribed to characteristic \(characteristic.uuid) and can handle: \(central.maximumUpdateValueLength)")
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

            CBBroadcaster.Service.characteristics = [CBBroadcaster.SegmentLengthCharacteristic, CBBroadcaster.SegmentDataCharacteristic]
            
            peripheralManager.add(CBBroadcaster.Service)
            
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [Globals.BluetoothGlobals.ServiceUUID]])
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
    
    func getCurrentSegmentLengthAsData() -> Data
    {
        var length = self.songData.count
        return Data.init(bytes: &length, count: MemoryLayout.size(ofValue: length))
    }
}
