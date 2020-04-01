//
//  PeripheralListener.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-03-27.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import Foundation
import CoreBluetooth
import AVFoundation

class PeripheralListener : NSObject, ObservableObject, CBPeripheralManagerDelegate, AVAssetResourceLoaderDelegate, StreamDelegate
{
    @Published var Connected = false
    @Published var data : Data = Data()
    
    static var Service = CBMutableService(type: Globals.BluetoothGlobals.ServiceUUID, primary: true)
    
    var TotalLength = Int64(UInt32.max)
    
    var channel : CBL2CAPChannel!
    
    var peripheralManager: CBPeripheralManager!
    
    var bytesPlayedSoFar = 0
    
    var currentlyPlayingAudio = false
    
    func startup()
    {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if(peripheral.state == .poweredOn)
        {
            NSLog("Bluetooth on peripheral listener")
            
              peripheralManager.add(PeripheralListener.Service)
                
              peripheralManager.publishL2CAPChannel(withEncryption: false)
            
              peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [Globals.BluetoothGlobals.ServiceUUID]])
            
            Connected = true 
        }
    }
    
    func playAudio(path: String)
    {
        if(self.currentlyPlayingAudio)
        {
            return
        }
        
        Globals.Playback.StreamingAsset = AVURLAsset.init(url: URL(fileURLWithPath: path))
        
        Globals.Playback.StreamingPlayerItem = AVPlayerItem.init(asset: Globals.Playback.StreamingAsset, automaticallyLoadedAssetKeys: ["playable"])
         
        Globals.Playback.StreamingPlayerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
         
        Globals.Playback.StreamingAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
         
        Globals.Playback.Player.automaticallyWaitsToMinimizeStalling = false
         
        Globals.Playback.Player.replaceCurrentItem(with: Globals.Playback.StreamingPlayerItem)
         
        Globals.Playback.Player.play()
        self.currentlyPlayingAudio = true
        print("Playing audio")
        
         if let error = Globals.Playback.Player.error
         {
             print("Error after playing audio: \(String(describing: error))")
         }
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let contentInfoRequest = loadingRequest.contentInformationRequest
        {
            NSLog("Got content request")
            contentInfoRequest.contentLength = Int64(UInt32.max)
            contentInfoRequest.contentType = AVFileType.mp4.rawValue
            contentInfoRequest.isByteRangeAccessSupported = true
            
            loadingRequest.finishLoading()
            return true
        }
        
        if let dataRequest = loadingRequest.dataRequest
        {
            let wholeDataSnapshot = data
            
            let amountCanSend = wholeDataSnapshot.count - self.bytesPlayedSoFar
            let chunk = 16384
            var returning : Data?
            
            if(amountCanSend >= chunk)
            {
                returning = wholeDataSnapshot.subdata(in: self.bytesPlayedSoFar..<(bytesPlayedSoFar + amountCanSend))
                print("Data \(wholeDataSnapshot.count) bytes : grabbed \(returning!.count)")
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
               if let error = Globals.Playback.Player.currentItem?.error
               {
                   NSLog("Error during playback: \(error)")
               }
           }
       }
    
    //L2CAP
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        if let error = error{
            print(error)
        }
        else
        {
            print("Peripheral: didPublish at \(PSM)")
        }
    }
    
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {

        if let error = error
        {
            print(error)
        }
        else
        {
            print("Peripheral: didOpen L2CAP")
            self.channel = channel
            self.channel.inputStream.delegate = self
            self.channel.inputStream.schedule(in: .current, forMode: .default)
            self.channel.inputStream.open()
        }
    }
    
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event)
    {
        switch(eventCode)
        {
            case .openCompleted:
                print("peripheral listener stream - opened stream")
                break
            case .hasBytesAvailable:
                print("peripheral listener stream - can read some bytes")
                var buffer = [UInt8].init(repeating: 0, count: Globals.ChunkSize)
                let count = (aStream as! InputStream).read(&buffer, maxLength: Globals.ChunkSize)
                appendData(data: Data(buffer).subdata(in: 0..<count))
                
                if(data.count >= 65535) //Magic number seems to work most cases.. need to find out real number
                {
                    playAudio(path: "specialscheme://some/station")
                }
                print("Adding \(count) bytes to data for total of \(self.data.count)")
                break
            case .endEncountered:
                print("End of stream with \(self.data.count) bytes collected")
            break
            default:
                print("peripheral listener stream - some other thing \(eventCode)")
                break
        }
    }
    
    func appendData(data : Data)
    {
        self.data.append(data)
    }
}
