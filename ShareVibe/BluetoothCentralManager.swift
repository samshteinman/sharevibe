//
//  BluetoothCentralManager.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-03-14.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import Foundation
import CoreBluetooth
import AVFoundation
import CryptoKit

class BluetoothCentralManager : NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, AVAssetResourceLoaderDelegate
{
    @Published var SegmentLength: UInt32 = 0
    @Published var SegmentDataReceivedSoFar : Int = 0
    @Published var Running = false
    @Published var Connected = false
    
    var segmentDataCharacteristic : CBCharacteristic!
    var segmentLengthCharacteristic : CBCharacteristic!
    
    var centralManager : CBCentralManager!
    var peripheral : CBPeripheral!
    
    var wholeData = Data()
    
    var streamingAsset : AVURLAsset!
    var streamingPlayerItem : AVPlayerItem!
    
    var currentlyReceivingSegmentIndex = -1
    var currentlyPlayingSegmentIndex = 0
    var bytesPlayedSoFar = 0
    
    var playing : Bool = false
            
    func startup()
    {
        if(!Running)
        {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
    
    public func centralManagerDidUpdateState(
        _ central: CBCentralManager)
    {
        if(central.state == .poweredOn)
        {
            Running = true
            print("Starting scan")
            centralManager.scanForPeripherals(withServices: [Globals.BluetoothGlobals.ServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
        else
        {
            Running = false
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.centralManager.stopScan()
        
        print("Found peripheral, connecting...!");
        
        self.peripheral = peripheral;
        self.peripheral.delegate = self;
        self.centralManager.connect(self.peripheral, options: nil);
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if(peripheral == self.peripheral)
        {
            print("Connected!");
            self.Connected = true
            peripheral.discoverServices([Globals.BluetoothGlobals.ServiceUUID]);
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    {
        if let services = peripheral.services
        {
            print("Found \(services.count) services")
            for service in services {
                if(service.uuid == Globals.BluetoothGlobals.ServiceUUID)
                {
                    print("Found service we were looking for")
                    peripheral.discoverCharacteristics([ Globals.BluetoothGlobals.CurrentFileSegmentDataUUID, Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID], for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error
        {
            print("Could not discover characteristics : \(error)")
        }
        else
        {
            print("Discovered some characteristics:")
            if let characteristics = service.characteristics
            {
                for characteristic in characteristics
                {
                    print(characteristic.uuid)
                    if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID)
                    {
                        peripheral.setNotifyValue(true, for: characteristic)
                        self.segmentLengthCharacteristic = characteristic
                    }
                    else if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentDataUUID)
                    {
                        peripheral.setNotifyValue(true, for: characteristic)
                        self.segmentDataCharacteristic = characteristic
                    }
                    else
                    {
                        print("discovered unknown characteristic")
                    }
                }
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("Did modify services")
        print("Searching for services again!");
            peripheral.discoverServices([Globals.BluetoothGlobals.ServiceUUID]);
        
    }
    
    func setupForReceivingNextSegment()
    {
        self.SegmentDataReceivedSoFar = 0
        self.currentlyReceivingSegmentIndex += 1
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID)
        {
            if let val = characteristic.value
            {
                setupForReceivingNextSegment()
                
                self.SegmentLength = (val.withUnsafeBytes
                    { (ptr: UnsafePointer<UInt32>) in ptr.pointee } )
                print("got segment length \(self.SegmentLength)")
            }
        }
        else if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentDataUUID)
        {
            if let val = characteristic.value
            {
                appendFileData(val: val)
                
                if(self.wholeData.count >= 32768)//33184)
                {
                    if(!self.playing)
                    {
                    print("Got enough bytes to start: \(self.currentlyReceivingSegmentIndex) : \(self.wholeData.count) bytes")
                        startPlayingStreamingAudio()
                        self.playing = true
                    }
                }
            }
        }
        else
        {
            print("Update value for uknown characteristic!")
        }
    }
    
    var currentSegmentHandleToFile : FileHandle?
    
    func appendFileData(val: Data)
    {
        self.SegmentDataReceivedSoFar += val.count
        wholeData.append(val)
    }

    public func startPlayingStreamingAudio()
    {
        playStream(path: "specialscheme://some/station")
    }
    
    public func playStream(path: String)
    {
        self.streamingAsset = AVURLAsset.init(url: URL(fileURLWithPath: path))
       
        self.streamingPlayerItem = AVPlayerItem.init(asset: self.streamingAsset, automaticallyLoadedAssetKeys: ["playable"])
        
        self.streamingAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        
        Globals.Playback.Player.automaticallyWaitsToMinimizeStalling = false
        
        Globals.Playback.Player.replaceCurrentItem(with: self.streamingPlayerItem)
        
        Globals.Playback.Player.play()
        if let error = Globals.Playback.Player.error
        {
            print("Error after play: \(String(describing: error))")
        }
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let contentInfoRequest = loadingRequest.contentInformationRequest
        {
            NSLog("Got content request")
            contentInfoRequest.contentLength = Int64(Int32(bitPattern: self.SegmentLength))
            contentInfoRequest.contentType = AVFileType.mp4.rawValue
            contentInfoRequest.isByteRangeAccessSupported = true
            
            loadingRequest.finishLoading()
            return true
        }
        
        if let dataRequest = loadingRequest.dataRequest
        {
            var amount = wholeData.count - self.bytesPlayedSoFar
            
            if(amount > 8192)
            {
                var returning = wholeData.subdata(in: self.bytesPlayedSoFar..<(bytesPlayedSoFar + amount))
                dataRequest.respond(with: returning)
                self.bytesPlayedSoFar += amount
                loadingRequest.finishLoading()
                return true
            }
            else if(self.bytesPlayedSoFar + 8192 > self.SegmentLength)
            {
                var returning = wholeData.subdata(in: self.bytesPlayedSoFar..<wholeData.count)
                dataRequest.respond(with: returning)
                self.bytesPlayedSoFar += amount
                loadingRequest.finishLoading()
                return true
            }
            else
            {
                loadingRequest.finishLoading()
                return true
            }
        }
        return false
    }
}
