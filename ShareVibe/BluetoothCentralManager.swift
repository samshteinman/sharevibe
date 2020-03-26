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
    
    var wholeData : Data?
    
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
            NSLog("Starting scan")
            centralManager.scanForPeripherals(withServices: [Globals.BluetoothGlobals.ServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
        else
        {
            Running = false
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.centralManager.stopScan()
        
        NSLog("Found peripheral, connecting...!");
        
        self.peripheral = peripheral;
        self.peripheral.delegate = self;
        self.centralManager.connect(self.peripheral, options: nil);
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if(peripheral == self.peripheral)
        {
            NSLog("Connected!");
            self.Connected = true
            peripheral.discoverServices([Globals.BluetoothGlobals.ServiceUUID]);
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    {
        if let services = peripheral.services
        {
            NSLog("Found \(services.count) services")
            for service in services {
                if(service.uuid == Globals.BluetoothGlobals.ServiceUUID)
                {
                    NSLog("Found service we were looking for")
                    peripheral.discoverCharacteristics([ Globals.BluetoothGlobals.CurrentFileSegmentDataUUID, Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID], for: service)
                }
            }
        }
        
        if let error = error
        {
            NSLog("Error when discovering services: \(error)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error
        {
            NSLog("Could not discover characteristics : \(error)")
        }
        else
        {
            NSLog("Discovered some characteristics:")
            if let characteristics = service.characteristics
            {
                for characteristic in characteristics
                {
                    NSLog(characteristic.uuid)
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
                        NSLog("discovered unknown characteristic")
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        NSLog("Did modify services")
        NSLog("Searching for services again!");
            peripheral.discoverServices([Globals.BluetoothGlobals.ServiceUUID]);
        
    }
        
    func restartPlayer()
    {
        Globals.Playback.Player.currentItem?.cancelPendingSeeks()
        Globals.Playback.Player.cancelPendingPrerolls()
        Globals.Playback.Player.replaceCurrentItem(with: nil)
        Globals.Playback.Player.pause()
    }
    
    func restart()
    {
        restartPlayer()
        
        self.playing = false
        self.wholeData = nil
        self.BytesReceivedOfCurrentSegmentSoFar = 0
        self.bytesPlayedSoFar = 0
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID)
        {
            if let val = characteristic.value
            {
                restart()
                
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
                
                if(self.wholeData!.count == self.SegmentLength)
                {
                    storeWholeData()
                }
                
                if(!self.playing && self.wholeData!.count >= 32768) //Magic number, won't play audio less.. why?
                {
                    startPlayingStreamingAudio()
                    self.playing = true
                }
            }
        }
        else
        {
            NSLog("Update value for uknown characteristic!")
        }
    }
    
    func storeWholeData()
    {
        do
        {
            if(FileManager.default.fileExists(atPath: Globals.ReceivedAudioFilePath.path))
            {
                try FileManager.default.removeItem(at: Globals.ReceivedAudioFilePath)
            }
            
            FileManager.default.createFile(atPath: Globals.ReceivedAudioFilePath.path, contents: self.wholeData!, attributes: nil)
        }
        catch
        {
         NSLog("Failed to write file : \(error)")
        }
    }
    
    func checkIfContainsMDAT(data: Data) -> Bool
    {
        for index in 0..<(data.count - 3)
        {
           if(data[index] == 0x6D
               && data[index+1] == 0x64
               && data[index+2] == 0x61
               && data[index+3] == 0x74)
           {
            return true
           }
        }
        
        return false
    }
    func appendFileData(val: Data)
    {
        if(wholeData == nil)
        {
            wholeData = val
        }
        else
        {
            wholeData!.append(val)
        }
    }

    public func startPlayingStreamingAudio()
    {
        playStream(path: "specialscheme://some/station")
    }
    
    public func playStream(path: String)
    {
        restartPlayer()
        
        self.streamingAsset = AVURLAsset.init(url: URL(fileURLWithPath: path))
       
        self.streamingPlayerItem = AVPlayerItem.init(asset: self.streamingAsset, automaticallyLoadedAssetKeys: ["playable"])
        
        self.streamingPlayerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        
        self.streamingAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        
        Globals.Playback.Player.automaticallyWaitsToMinimizeStalling = false
        
        Globals.Playback.Player.replaceCurrentItem(with: self.streamingPlayerItem)
        
        Globals.Playback.Player.play()
        UIApplication.shared.isIdleTimerDisabled = false
        if let error = Globals.Playback.Player.error
        {
            NSLog("Error after play: \(String(describing: error))")
        }
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let contentInfoRequest = loadingRequest.contentInformationRequest
        {
            NSLog("Got content request")
            contentInfoRequest.contentLength = Int64(bitPattern: UInt64(self.SegmentLength))
            contentInfoRequest.contentType = AVFileType.mp4.rawValue
            contentInfoRequest.isByteRangeAccessSupported = true
            
            loadingRequest.finishLoading()
            return true
        }
        
        if let dataRequest = loadingRequest.dataRequest
        {
            let wholeDataSnapshot = wholeData
            if(wholeDataSnapshot == nil)
            {
                return false
            }
            
            let amount = wholeDataSnapshot!.count - self.bytesPlayedSoFar
            let chunk = 16384
            var returning : Data?
            
            if(amount > chunk)
            {
                returning = wholeDataSnapshot!.subdata(in: self.bytesPlayedSoFar..<(bytesPlayedSoFar + chunk))
            }
            else if(self.bytesPlayedSoFar + chunk > self.SegmentLength)
            {
                returning = wholeDataSnapshot!.subdata(in: self.bytesPlayedSoFar..<wholeDataSnapshot!.count)
            }
            else
            {
                loadingRequest.finishLoading()
                return true
            }
            
            dataRequest.respond(with: returning!)
            self.bytesPlayedSoFar += returning!.count
            loadingRequest.finishLoading()
            return true
        }
        return false
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if(keyPath == "status")
        {
            if let error = Globals.Playback.Player.currentItem?.error
            {
                NSLog("Error during playback: \(error)")
            }
        }
    }
}
