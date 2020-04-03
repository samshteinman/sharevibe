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

class CBListener : NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, AVAssetResourceLoaderDelegate
{
    var ExpectedLength: UInt64 = 0
    @Published var BytesReceivedSoFar: UInt64 = 0
    
    @Published var Listening = false
    
    @Published var SongDescription: String?
    
    var centralManager : CBCentralManager!
    var peripheral : CBPeripheral!
    
    var wholeData : Data?

    var streamingAsset : AVURLAsset!
    var streamingPlayerItem : AVPlayerItem!
    var fileHandle : FileHandle!
    
    var bytesPlayedSoFar = 0
    @Published var startedPlayingAudio = false
    
    func startup()
    {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        Globals.Playback.setupRemoteControls()
    }
    
    public func centralManagerDidUpdateState(
        _ central: CBCentralManager)
    {
        if(central.state == .poweredOn)
        {
            NSLog("Starting scan")
            Listening = true
            centralManager.scanForPeripherals(withServices: [Globals.BluetoothGlobals.ServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
        else
        {
            Listening = false
            //TODO: Alert that something's wrong with bluetooth
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
                    peripheral.discoverCharacteristics([ Globals.BluetoothGlobals.SongDataUUID, Globals.BluetoothGlobals.SongLengthUUID, Globals.BluetoothGlobals.SongDescriptionUUID,
                    Globals.BluetoothGlobals.SongControlUUID], for: service)
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
                    NSLog("\(characteristic.uuid)")
                    peripheral.setNotifyValue(true, for: characteristic)
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
        
        self.startedPlayingAudio = false
        self.wholeData = nil
        self.BytesReceivedSoFar = 0
        self.bytesPlayedSoFar = 0
        setupFileHandle()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if(characteristic.uuid == Globals.BluetoothGlobals.SongLengthUUID)
        {
            if let val = characteristic.value
            {
                restart()
                
                UIApplication.shared.isIdleTimerDisabled = true

                self.ExpectedLength = (val.withUnsafeBytes
                    { (ptr: UnsafePointer<UInt64>) in ptr.pointee } )
                NSLog("Got segment length \(self.ExpectedLength)")
            }
        }
        else if(characteristic.uuid == Globals.BluetoothGlobals.SongDataUUID)
        {
            if let val = characteristic.value
            {
                appendFileData(val: val)
                
                self.BytesReceivedSoFar += UInt64(val.count)
                
                if(!self.startedPlayingAudio && self.wholeData!.count > Globals.Playback.StartPlayBytes)
                {
                    startPlayingStreamingAudio()
                    //TODO: Handler for when a song finishes
                }
            }
        }
        else if(characteristic.uuid == Globals.BluetoothGlobals.SongDescriptionUUID)
        {
            if let val = characteristic.value
            {
                self.SongDescription = String(decoding: val, as: UTF8.self)
            }
        }
        else
        {
            NSLog("Update value for uknown characteristic!")
        }
    }
    
    func setupFileHandle()
    {
        do
       {
           if(FileManager.default.fileExists(atPath: Globals.ReceivedAudioFilePath.path))
           {
               try FileManager.default.removeItem(at: Globals.ReceivedAudioFilePath)
           }
           
            FileManager.default.createFile(atPath: Globals.ReceivedAudioFilePath.path, contents: nil, attributes: nil)
        
            self.fileHandle = try FileHandle.init(forUpdating: Globals.ReceivedAudioFilePath)
       }
       catch
       {
        NSLog("Failed to write file : \(error)")
       }
    }
    func appendFileData(val: Data)
    {
        if wholeData == nil
        {
            NSLog("wholeData empty adding \(val.count) bytes")
            wholeData = val
        }
        else
        {
            wholeData!.append(val)
            NSLog("Storing \(val.count) bytes")
        }
        
        if self.fileHandle == nil
        {
            setupFileHandle()
        }
        
        self.fileHandle.write(val)
    }

    public func startPlayingStreamingAudio()
    {
        self.startedPlayingAudio = true
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
            contentInfoRequest.contentLength = Int64(bitPattern: UInt64(self.ExpectedLength))
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
            
            if self.bytesPlayedSoFar == self.ExpectedLength
            {
                NSLog("Finished playback")
                loadingRequest.finishLoading()
                return false
            }
            else if amount > chunk
            {
                returning = wholeDataSnapshot!.subdata(in: self.bytesPlayedSoFar..<(bytesPlayedSoFar + chunk))
            }
            else if self.bytesPlayedSoFar + chunk > self.ExpectedLength
            {
                returning = wholeDataSnapshot!.subdata(in: self.bytesPlayedSoFar..<wholeDataSnapshot!.count)
            }
            else
            {
                loadingRequest.finishLoading()
                return true
            }
            NSLog("Sending up \(returning!.count) bytes")
            
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
            print("playback currentitem : \(Globals.Playback.Player.currentItem!)")
            if let error = Globals.Playback.Player.currentItem?.error
            {
                NSLog("Error during playback: \(error)")
            }
        }
    }
}
