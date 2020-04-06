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
    var centralManager : CBCentralManager!
    
    @Published var BytesReceivedSoFar: UInt64 = 0
    @Published var ExpectedAmountOfBytes: UInt64 = 0
    
    @Published var Status : String = ""
    
    @Published var Scanning = false
    @Published var BufferingAudio = false
    
    var dataReceived : Data?
    
    @Published var startedPlayingAudio = false
    
    @Published var currentlyListeningToStation : Station?
    @Published var fullyDiscoveredStations = Dictionary<UUID,Station>()
    var currentlyDiscoveringStations = Dictionary<UUID,Station>()
    
    func setup()
    {
        Globals.Playback.setupPlaybackBackgroundControls()
    }
    
    func startScanningForStations()
    {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    
    public func centralManagerDidUpdateState(
        _ central: CBCentralManager)
    {
        if(central.state == .poweredOn)
        {
            NSLog("Starting scan")
            Scanning = true
            centralManager.scanForPeripherals(withServices: [Globals.BluetoothGlobals.ServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
        else
        {
            Scanning = false
            Status = "Could not start Bluetooth! Please restart the app."
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        //When scanning: peripherals are always advertising, even ones I've connected to
        createOrUpdateStation(id: peripheral.identifier , peripheral: peripheral)
        
        if !self.centralManager.retrieveConnectedPeripherals(withServices: [Globals.BluetoothGlobals.ServiceUUID]).contains(peripheral)
        {
            NSLog("Found peripheral, connecting...!");
            
            peripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil);
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("Connected!");
        peripheral.discoverServices([Globals.BluetoothGlobals.ServiceUUID]);
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    {
        if let services = peripheral.services
        {
            NSLog("Found \(services.count) services")
            if(services.count == 0)
            {
                NSLog("No services available on \(peripheral), disconnecting")
                self.centralManager.cancelPeripheralConnection(peripheral)
                return
            }
            
            if(services[0].uuid == Globals.BluetoothGlobals.ServiceUUID)
            {
                NSLog("Found service we were looking for")
                if currentlyListeningToStation?.id == peripheral.identifier
                {
                    peripheral.discoverCharacteristics(nil, for: services[0])
                }
                else
                {
                    peripheral.discoverCharacteristics([
                        Globals.BluetoothGlobals.RoomNameUUID,
                        Globals.BluetoothGlobals.NumberOfListenersUUID], for: services[0])
                    
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
                       if characteristic.uuid == Globals.BluetoothGlobals.RoomNameUUID
                           ||
                           characteristic.uuid == Globals.BluetoothGlobals.NumberOfListenersUUID
                       {
                           peripheral.readValue(for: characteristic)
                           NSLog("Request\(characteristic.uuid)")
                           peripheral.setNotifyValue(true, for: characteristic)
                       }
                       else
                       {
                           if currentlyListeningToStation?.id == peripheral.identifier
                           {
                               NSLog("\(characteristic.uuid)")
                               peripheral.setNotifyValue(true, for: characteristic)
                           }
                       }
                   }
               }
           }
       }
    
    func createOrUpdateStation(id: UUID, name: String? = nil, numberOfListeners: Int? = nil, peripheral : CBPeripheral? = nil, service : CBService? = nil)
    {
        if fullyDiscoveredStations[id] != nil
        {
            NSLog("Already fully discovered, updating state.")
            if let num = numberOfListeners
            {
                fullyDiscoveredStations[id]!.NumberOfListeners = num
            }
            if let unpackedName = name
            {
                fullyDiscoveredStations[id]!.Name = unpackedName
            }
        }
        else
        {
            if let station = currentlyDiscoveringStations[id]
            {
                currentlyDiscoveringStations[id]?.Name = name ?? station.Name
                currentlyDiscoveringStations[id]?.NumberOfListeners = numberOfListeners ?? station.NumberOfListeners
                currentlyDiscoveringStations[id]?.peripheral = peripheral ?? station.peripheral
                currentlyDiscoveringStations[id]?.service = service ?? station.service
            }
            else
            {
                currentlyDiscoveringStations[id] = Station(id: id, peripheral: peripheral , service: service, NumberOfListeners: numberOfListeners, Name: name)
            }
            
            let station = currentlyDiscoveringStations[id]!
            
            if station.Name != nil && station.NumberOfListeners != nil
            {
                fullyDiscoveredStations[station.id] = station
                currentlyDiscoveringStations.removeValue(forKey: station.id)
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == Globals.BluetoothGlobals.RoomNameUUID
        {
            //TODO: Timing? Multiple calls to this?
            if let val = characteristic.value
            {
                createOrUpdateStation(id: peripheral.identifier, name: String(bytes: val, encoding: .utf8))
            }
        }
        else if characteristic.uuid == Globals.BluetoothGlobals.NumberOfListenersUUID
        {
            //TODO: Timing? Multiple calls to this?
            if let val = characteristic.value
            {
                createOrUpdateStation(id: peripheral.identifier, numberOfListeners: (val.withUnsafeBytes
                    { (ptr: UnsafePointer<Int>) in ptr.pointee } ))
            }
        }
        else if(characteristic.uuid == Globals.BluetoothGlobals.SongLengthUUID)
        {
            if let val = characteristic.value
            {
                restart()
                
                UIApplication.shared.isIdleTimerDisabled = true
                
                self.ExpectedAmountOfBytes = (val.withUnsafeBytes
                    { (ptr: UnsafePointer<UInt64>) in ptr.pointee } )
                NSLog("Got expected length \(self.ExpectedAmountOfBytes)")
            }
        }
        else if(characteristic.uuid == Globals.BluetoothGlobals.SongDataUUID)
        {
            if let val = characteristic.value
            {
                appendFileData(val: val)
                
                self.BytesReceivedSoFar += UInt64(val.count)
                
                BufferingAudio = self.BytesReceivedSoFar > 0 && self.BytesReceivedSoFar < Globals.Playback.AmountOfBytesBeforeAudioCanStart
                
                if(!self.startedPlayingAudio && self.dataReceived!.count > Globals.Playback.AmountOfBytesBeforeAudioCanStart)
                {
                    startPlayingStreamingAudio()
                }
            }
        }
        else if(characteristic.uuid == Globals.BluetoothGlobals.SongDescriptionUUID)
        {
            if let val = characteristic.value
            {
                //         self.SongDescription = String(decoding: val, as: UTF8.self)
            }
        }
        else
        {
            NSLog("Update value for uknown characteristic!")
        }
    }
    
    
    
   
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        NSLog("Did modify services")
        NSLog("Searching for services again!");
        peripheral.discoverServices([Globals.BluetoothGlobals.ServiceUUID]);
        
    }
    
    func restart()
    {
        Globals.Playback.RestartPlayer()
        
        self.BufferingAudio = false
        self.startedPlayingAudio = false
        self.dataReceived = nil
        self.BytesReceivedSoFar = 0
        Globals.Playback.BytesPlayedSoFar = 0
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("Disconnected from \(peripheral)")
    }
    
    func appendFileData(val: Data)
    {
        if dataReceived == nil
        {
            NSLog("dataReceived empty adding \(val.count) bytes")
            dataReceived = val
        }
        else
        {
            dataReceived!.append(val)
            NSLog("Storing \(val.count) bytes")
        }
    }
    
    public func startPlayingStreamingAudio()
    {
        self.startedPlayingAudio = true
        playStream(path: "specialscheme://some/station")
    }
    
    @objc func playerDidFinishPlaying(note: Notification)
    {
        restart()
    }
    
    public func playStream(path: String)
    {
        Globals.Playback.RestartPlayer()
        
        Globals.Playback.StreamingAsset = AVURLAsset.init(url: URL(fileURLWithPath: path))
        
        Globals.Playback.StreamingPlayerItem = AVPlayerItem.init(asset: Globals.Playback.StreamingAsset, automaticallyLoadedAssetKeys: ["playable"])
        
        Globals.Playback.StreamingPlayerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        Globals.Playback.StreamingAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        
        Globals.Playback.Player.automaticallyWaitsToMinimizeStalling = false
        
        Globals.Playback.Player.replaceCurrentItem(with: Globals.Playback.StreamingPlayerItem)
        
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
            contentInfoRequest.contentLength = Int64(bitPattern: UInt64(self.ExpectedAmountOfBytes))
            contentInfoRequest.contentType = AVFileType.mp4.rawValue
            contentInfoRequest.isByteRangeAccessSupported = true
            
            loadingRequest.finishLoading()
            return true
        }
        
        if let dataRequest = loadingRequest.dataRequest
        {
            let dataReceivedSnapshot = dataReceived
            if(dataReceivedSnapshot == nil)
            {
                return false
            }
            
            let amount = dataReceivedSnapshot!.count - Globals.Playback.BytesPlayedSoFar
            let chunk = 16384
            var returning : Data?
            
            if Globals.Playback.BytesPlayedSoFar == self.ExpectedAmountOfBytes
            {
                NSLog("Finished playback")
                loadingRequest.finishLoading()
                return false
            }
            else if amount > chunk
            {
                returning = dataReceivedSnapshot!.subdata(in: Globals.Playback.BytesPlayedSoFar..<(Globals.Playback.BytesPlayedSoFar + chunk))
            }
            else if Globals.Playback.BytesPlayedSoFar + chunk > self.ExpectedAmountOfBytes
            {
                returning = dataReceivedSnapshot!.subdata(in: Globals.Playback.BytesPlayedSoFar..<dataReceivedSnapshot!.count)
            }
            else
            {
                loadingRequest.finishLoading()
                return true
            }
            NSLog("Sending up \(returning!.count) bytes")
            
            dataRequest.respond(with: returning!)
            Globals.Playback.BytesPlayedSoFar += returning!.count
            loadingRequest.finishLoading()
            return true
        }
        return false
    }
    
    func startListeningToStation(id: UUID)
    {
        if let currentStation = currentlyListeningToStation
        {
            if currentStation.id == id
            {
                return
            }
        }
        
        if let peripheral = fullyDiscoveredStations[id]?.peripheral
        {
            self.centralManager.stopScan()
            currentlyListeningToStation = fullyDiscoveredStations[id]
            
            for peripheral in self.centralManager.retrieveConnectedPeripherals(withServices: [Globals.BluetoothGlobals.ServiceUUID])
            {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("Failed to connect to \(peripheral)")
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
