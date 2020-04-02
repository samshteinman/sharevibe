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
import MediaPlayer

class CBListener : NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, AVAssetResourceLoaderDelegate
{
    @Published var SegmentLength: UInt64 = 0
    @Published var BytesReceivedOfCurrentSegmentSoFar: UInt64 = 0
    @Published var Running = false
    @Published var Connected = false
    @Published var SongDescription : String?
    
    var centralManager : CBCentralManager!
    var peripheral : CBPeripheral!
    
    var wholeData : Data?

    var streamingAsset : AVURLAsset!
    var streamingPlayerItem : AVPlayerItem!
    var fileHandle : FileHandle!
    
    var bytesPlayedSoFar = 0
    var startedPlayingAudio = false
    
    func startup()
    {
        if(!Running)
        {
            centralManager = CBCentralManager(delegate: self, queue: nil)
            setupRemoteControls()
        }
    }
    
    func setupRemoteControls()
    {
            // Get the shared MPRemoteCommandCenter
            let commandCenter = MPRemoteCommandCenter.shared()

            // Add handler for Play Command
            commandCenter.playCommand.addTarget { [unowned self] event in
                if Globals.Playback.Player.rate == 0.0 {
                    Globals.Playback.Player.play()
                    return .success
                }
                return .commandFailed
            }

            // Add handler for Pause Command
            commandCenter.pauseCommand.addTarget { [unowned self] event in
                if Globals.Playback.Player.rate == 1.0 {
                   Globals.Playback.Player.pause()
                    return .success
                }
                return .commandFailed
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
                    peripheral.discoverCharacteristics([ Globals.BluetoothGlobals.CurrentFileSegmentDataUUID, Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID, Globals.BluetoothGlobals.SongDescriptionUUID], for: service)
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
        
        var startedPlayingAudio = false
        self.wholeData = nil
        self.BytesReceivedOfCurrentSegmentSoFar = 0
        self.bytesPlayedSoFar = 0
        setupFileHandle()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID)
        {
            if let val = characteristic.value
            {
                restart()
                
                UIApplication.shared.isIdleTimerDisabled = true

                self.SegmentLength = (val.withUnsafeBytes
                    { (ptr: UnsafePointer<UInt64>) in ptr.pointee } )
                NSLog("Got segment length \(self.SegmentLength)")
            }
        }
        else if(characteristic.uuid == Globals.BluetoothGlobals.CurrentFileSegmentDataUUID)
        {
            if let val = characteristic.value
            {
                appendFileData(val: val)
                
                self.BytesReceivedOfCurrentSegmentSoFar += UInt64(val.count)
                
                if(!self.startedPlayingAudio && self.wholeData!.count > 65535)
                {
                    startPlayingStreamingAudio()
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
