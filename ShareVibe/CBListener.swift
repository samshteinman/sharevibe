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
    
    @Published var BytesReceivedSoFar: Int = 0
    @Published var ExpectedAmountOfBytes: Int = 0
    
    @Published var Status : String = ""
    @Published var HasError : Bool = false
    
    @Published var Scanning = false
    @Published var BufferingAudio = false
    
    var dataReceived : Data?
    
    @Published var startedPlayingAudio = false
    @Published var isMuted = false
    
    @Published var currentlyListeningToStation : Station?
    @Published var fullyDiscoveredStations = Dictionary<UUID,Station>()
    var currentlyDiscoveringStations = Dictionary<UUID,Station>()
    
    func startup()
    {
        if centralManager == nil
        {
            Status = Globals.Playback.Status.settingUp
            
            centralManager = CBCentralManager(delegate: self, queue: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        }
    }
    
    func shutdown()
    {
        reset()
        centralManager.stopScan()
    }
    
    func reset()
    {
        restartReceivingAudio()
        cancelAllConnections()
        clearAllStationLists()
        currentlyListeningToStation = nil
        HasError = false
    }
    
    func restart()
    {
        reset()
        startScanningForStations()
    }
    
    public func centralManagerDidUpdateState(
        _ central: CBCentralManager)
    {
        if(central.state == .poweredOn)
        {
            NSLog("Starting scan")
            startScanningForStations()
        }
        else
        {
            Scanning = false
            HasError = true
            Status = Globals.Playback.Status.failedBluetooth
        }
    }
    
    func startScanningForStations()
    {
        Scanning = true
        
        Status = Globals.Playback.Status.scanningForStations
        
        centralManager.scanForPeripherals(withServices: [Globals.Bluetooth.ServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        //When scanning: peripherals are always advertising, even ones I've connected to
        createOrUpdateStation(id: peripheral.identifier , peripheral: peripheral)
        
        if !self.centralManager.retrieveConnectedPeripherals(withServices: [Globals.Bluetooth.ServiceUUID]).contains(peripheral)
        {
            NSLog("Found peripheral, connecting for inquiry...!");
            
            peripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil);
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("Connected to \(peripheral) Discovering services....");
        peripheral.discoverServices([Globals.Bluetooth.ServiceUUID]);
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
            
            if(services[0].uuid == Globals.Bluetooth.ServiceUUID)
            {
                NSLog("Found service we were looking for \(peripheral), discovering characteristics")
                
                if currentlyListeningToStation?.id == peripheral.identifier
                {
                    peripheral.discoverCharacteristics(nil, for: services[0])
                }
                else
                {
                    peripheral.discoverCharacteristics([
                        Globals.Bluetooth.RoomNameUUID,
                        Globals.Bluetooth.NumberOfListenersUUID], for: services[0])
                    
                }
            }
        }
        
        if let error = error
        {
            NSLog("Error when discovering services: \(error)")
            //Silently fail here, don't want to error on a bad peripheral
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error
        {
            NSLog("Could not discover characteristics : \(error)")
        }
        else
        {
            if let characteristics = service.characteristics
            {
                NSLog("Discovered \(characteristics.count) characteristics:")
                
                for characteristic in characteristics
                {
                    if characteristic.uuid == Globals.Bluetooth.RoomNameUUID
                        ||
                        characteristic.uuid == Globals.Bluetooth.NumberOfListenersUUID
                    {
                        peripheral.readValue(for: characteristic)
                        NSLog("Request read on \(characteristic.uuid)")
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                    else
                    {
                        if currentlyListeningToStation?.id == peripheral.identifier
                        {
                            NSLog("\(characteristic.uuid)")
                            peripheral.setNotifyValue(true, for: characteristic)
                            Status = Globals.Playback.Status.noSongCurrentlyPlaying
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
            NSLog("Already fully discovered \(id), updating state.")
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
        if characteristic.uuid == Globals.Bluetooth.RoomNameUUID
        {
            //TODO: Timing? Multiple calls to this?
            if let val = characteristic.value
            {
                createOrUpdateStation(id: peripheral.identifier, name: String(bytes: val, encoding: .utf8))
            }
        }
        else if characteristic.uuid == Globals.Bluetooth.NumberOfListenersUUID
        {
            //TODO: Timing? Multiple calls to this?
            if let val = characteristic.value
            {
                createOrUpdateStation(id: peripheral.identifier, numberOfListeners: (val.withUnsafeBytes
                    { (ptr: UnsafePointer<Int>) in ptr.pointee } ))
            }
        }
        else if(characteristic.uuid == Globals.Bluetooth.SongLengthUUID)
        {
            if let val = characteristic.value
            {
                restartReceivingAudio()
                
                self.ExpectedAmountOfBytes = (val.withUnsafeBytes
                    { (ptr: UnsafePointer<Int>) in ptr.pointee } )
                NSLog("Got expected length \(self.ExpectedAmountOfBytes)")
            }
        }
        else if(characteristic.uuid == Globals.Bluetooth.SongDataUUID)
        {
            if self.ExpectedAmountOfBytes <= 0
            {
                Status = Globals.Playback.Status.waitingForCurrentSongToFinish
                //TODO: Be able to tell them how long it will be until song finishes
                return
            }
            
            if let val = characteristic.value
            {
                appendFileData(val: val)
                
                self.BytesReceivedSoFar += val.count
                
                BufferingAudio = self.BytesReceivedSoFar > 0 && self.BytesReceivedSoFar < Globals.Playback.AmountOfBytesBeforeAudioCanStartListener
                
                if(BufferingAudio && Status != Globals.Playback.Status.bufferingSong)
                {
                    Status = Globals.Playback.Status.bufferingSong
                }
                
                if(!self.startedPlayingAudio && self.BytesReceivedSoFar > Globals.Playback.AmountOfBytesBeforeAudioCanStartListener)
                {
                    startPlayingStreamingAudio()
                }
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
        peripheral.discoverServices([Globals.Bluetooth.ServiceUUID]);
        
    }
    
    func restartReceivingAudio()
    {
        self.dataReceived = nil
        Globals.Playback.RestartPlayer()
        
        self.Status = Globals.Playback.Status.noSongCurrentlyPlaying
        self.BufferingAudio = false
        self.startedPlayingAudio = false
        self.BytesReceivedSoFar = 0
        self.ExpectedAmountOfBytes = 0
        Globals.Playback.BytesPlayedSoFar = 0
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("Disconnected from \(peripheral)")
        if let station = self.currentlyListeningToStation
        {
            if station.peripheral?.identifier == peripheral.identifier
            {
                NSLog("Disconnected from currently listening to \(peripheral) , restarting scan")
                restart()
            }
        }
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
        restartReceivingAudio()
        Status = Globals.Playback.Status.noSongCurrentlyPlaying
    }
    
    public func playStream(path: String)
    {
        Globals.Playback.RestartPlayer()
        
        Globals.Playback.StreamingAsset = AVURLAsset.init(url: URL(fileURLWithPath: path))
        
        Globals.Playback.StreamingPlayerItem = AVPlayerItem.init(asset: Globals.Playback.StreamingAsset, automaticallyLoadedAssetKeys: ["playable"])
        
        Globals.Playback.StreamingPlayerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        
        Globals.Playback.StreamingAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.global())
        
        Globals.Playback.Player.automaticallyWaitsToMinimizeStalling = false
        
        Globals.Playback.Player.replaceCurrentItem(with: Globals.Playback.StreamingPlayerItem)
        
        NSLog("Starting playing audio")
        Globals.Playback.Player.play()
        
        if let error = Globals.Playback.Player.error
        {
            NSLog("Error after play: \(String(describing: error))")
            HasError = true
            Status = Globals.Playback.Status.errorPlayingSong
        }
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        if let contentInfoRequest = loadingRequest.contentInformationRequest
        {
            contentInfoRequest.contentLength = Int64(bitPattern: UInt64(self.ExpectedAmountOfBytes))
            NSLog("Got content request responding with \(contentInfoRequest.contentLength)")
            
            contentInfoRequest.contentType = AVFileType.mp4.rawValue
            contentInfoRequest.isByteRangeAccessSupported = true
            
            loadingRequest.finishLoading()
            return true
        }
        
        if let dataRequest = loadingRequest.dataRequest
        {
            NSLog("Got data request start: \(dataRequest.requestedOffset) length: \(dataRequest.requestedLength)")
            
            let dataReceivedSnapshot = dataReceived
            if dataReceivedSnapshot == nil || dataReceivedSnapshot!.count == 0
            {
                NSLog("Sending up 0 bytes becuse data is nil or 0 \(dataReceivedSnapshot)")
                loadingRequest.finishLoading()
                return true
            }
            
            let amountCanSupply = dataReceivedSnapshot!.count - Globals.Playback.BytesPlayedSoFar
            let chunk = 16384
            var returning : Data?
            
            if Globals.Playback.BytesPlayedSoFar == self.ExpectedAmountOfBytes
            {
                NSLog("Finished playback")
                loadingRequest.finishLoading()
                return false
            }
            else if amountCanSupply > chunk
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
    
    func clearAllStationLists()
    {
        self.fullyDiscoveredStations = Dictionary<UUID,Station>()
        self.currentlyDiscoveringStations = Dictionary<UUID,Station>()
        self.currentlyListeningToStation = nil
    }
    
    
    func clearAllStationsBut(station : Station)
    {
        for (id,station) in fullyDiscoveredStations
        {
            if id != station.id
            {
                fullyDiscoveredStations[id] = nil
            }
        }
        self.currentlyDiscoveringStations = Dictionary<UUID,Station>()
    }
    
    func cancelAllConnections()
    {
        for peripheral in self.centralManager.retrieveConnectedPeripherals(withServices: [Globals.Bluetooth.ServiceUUID])
        {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func cancelAllConnectionsBut( exceptPeripheral : CBPeripheral) -> Bool
       {
        var isCurrentlyConnected = false
           for peripheral in self.centralManager.retrieveConnectedPeripherals(withServices: [Globals.Bluetooth.ServiceUUID])
           {
            if(exceptPeripheral == peripheral)
            {
                isCurrentlyConnected = true
            } else
            {
               centralManager.cancelPeripheralConnection(peripheral)
            }
           }
        
        return isCurrentlyConnected
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
            
            let isCurrentlyConnected = cancelAllConnectionsBut(exceptPeripheral: peripheral)
            
            currentlyListeningToStation = fullyDiscoveredStations[id]
            
            clearAllStationsBut(station: currentlyListeningToStation!)
            
            if(isCurrentlyConnected)
            {
                peripheral.discoverServices([Globals.Bluetooth.ServiceUUID]);
            }
            else
            {
                centralManager.connect(peripheral, options: nil)
            }
            
            Status = Globals.Playback.Status.connecting
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("Failed to connect to \(peripheral)")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if(keyPath == "status")
        {
            print("Playback currentitem : \(Globals.Playback.Player.currentItem!) status: \(Globals.Playback.Player.status) \(Globals.Playback.Player.status.rawValue))")
            if let error = Globals.Playback.Player.currentItem?.error
            {
                NSLog("Error during playback: \(error)")
            }
        }
    }
}
