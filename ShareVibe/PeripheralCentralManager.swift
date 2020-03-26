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

class PeripheralCentralManager : NSObject, ObservableObject, CBPeripheralManagerDelegate, MPMediaPickerControllerDelegate
{
    @Published var BytesSentOfCurrentSegmentSoFar: Int = 0
    @Published var TotalBytesOfCurrentSegment: Int = 0
    @Published var Running = false
    @Published var Connected = false
    
    var songData : Data!
    var needBroadcastSegmentLength = true
    
    var peripheralManager: CBPeripheralManager!
    
    static var Service = CBMutableService(type: Globals.BluetoothGlobals.ServiceUUID, primary: true)
    static var SegmentCharacteristicProperties: CBCharacteristicProperties = [.notify, .read, .write]
    static var Permissions: CBAttributePermissions = [.readable, .writeable]
    static var SegmentLengthCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID, properties: SegmentCharacteristicProperties, value: nil, permissions: Permissions)
    static var SegmentDataCharacteristic = CBMutableCharacteristic(type: Globals.BluetoothGlobals.CurrentFileSegmentDataUUID, properties: SegmentCharacteristicProperties, value: nil, permissions: Permissions)
    
    func startup()
    {
        if(!Running)
        {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
    }
    
    func reset()
    {
        self.needBroadcastSegmentLength = true
        self.BytesSentOfCurrentSegmentSoFar = 0
    }
    
    func startSend(content : Data)
    {
        reset()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.songData = content
        
        tryBroadcastSegmentLength()
        
        sendWholeSegment()
    }
    
    func sendWholeSegment()
    {
        while(self.BytesSentOfCurrentSegmentSoFar < self.songData.count)
        {
            if let chunk = GetChunkFromCurrentSegment()
            {
                if(peripheralManager.updateValue(chunk, for: PeripheralCentralManager.SegmentDataCharacteristic, onSubscribedCentrals: nil))
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
            
            self.needBroadcastSegmentLength = !peripheralManager.updateValue(getCurrentSegmentLengthAsData() ,for: PeripheralCentralManager.SegmentLengthCharacteristic, onSubscribedCentrals: nil)
            
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
        continueSending()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        self.Connected = true
        
        print("Someone subscribed to characteristic \(characteristic.uuid) and can handle: \(central.maximumUpdateValueLength)")
        if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentDataUUID)
        {
            print("Updating file data chunk maximum size to \(central.maximumUpdateValueLength)")
            Globals.ChunkSize = central.maximumUpdateValueLength
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
          if(peripheral.state == .poweredOn)
          {
            print("Ready to advertise")
            Running = true
            
            PeripheralCentralManager.Service.characteristics = [PeripheralCentralManager.SegmentLengthCharacteristic, PeripheralCentralManager.SegmentDataCharacteristic]
            
            peripheralManager.add(PeripheralCentralManager.Service)
            
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
            return self.songData.subdata(in: BytesSentOfCurrentSegmentSoFar..<(self.songData.count))
        }
        else
        {
            return self.songData.subdata(in: BytesSentOfCurrentSegmentSoFar..<(BytesSentOfCurrentSegmentSoFar+Globals.ChunkSize))
        }
    }
    
    func getCurrentSegmentLengthAsData() -> Data
    {
        var length = self.songData.count
        return Data.init(bytes: &length, count: MemoryLayout.size(ofValue: length))
    }
}
