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
import UIKit

class BluetoothCentralManager : NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, AVAssetResourceLoaderDelegate
{
    @Published var SegmentLength: UInt32 = 0
    @Published var BytesReceivedOfCurrentSegmentSoFar: Int = 0
    @Published var Running = false
    @Published var Connected = false
    
    var segmentDataCharacteristic : CBCharacteristic!
    var segmentLengthCharacteristic : CBCharacteristic!
    
    var centralManager : CBCentralManager!
    var peripheral : CBPeripheral!
    
    var wholeData = Data()
    
    var streamingAsset : AVURLAsset!
    var streamingPlayerItem : AVPlayerItem!
    
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
        
    func restartPlayer()
    {
        self.playing = false
        self.wholeData = Data()
        self.BytesReceivedOfCurrentSegmentSoFar = 0
        self.bytesPlayedSoFar = 0
        Globals.Playback.Player.pause()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID)
        {
            if let val = characteristic.value
            {
                restartPlayer()
                UIApplication.shared.isIdleTimerDisabled = true
                
                self.SegmentLength = (val.withUnsafeBytes
                    { (ptr: UnsafePointer<UInt32>) in ptr.pointee } )
                NSLog("Got segment length \(self.SegmentLength)")
            }
        }
        else if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentDataUUID)
        {
            if let val = characteristic.value
            {
                appendFileData(val: val)
                
                self.BytesReceivedOfCurrentSegmentSoFar += val.count
                
                if(self.wholeData.count >= 32768)
                {
                    if(!self.playing)
                    {
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
    
    func appendFileData(val: Data)
    {
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
        UIApplication.shared.isIdleTimerDisabled = false
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
            var chunk = 16384
            if(amount > chunk)
            {
                var returning = wholeData.subdata(in: self.bytesPlayedSoFar..<(bytesPlayedSoFar + chunk))
                dataRequest.respond(with: returning)
                self.bytesPlayedSoFar += chunk
                loadingRequest.finishLoading()
                return true
            }
            else if(self.bytesPlayedSoFar + chunk > self.SegmentLength)
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
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        
    }
}
