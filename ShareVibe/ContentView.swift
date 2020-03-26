//
//  ContentView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-03-13.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI
import MediaPlayer
import AVFoundation
import FileProvider

struct ContentView: View {
    @State private var songs : MPMediaItemCollection?
    @State private var showPicker : Bool = false
    @State private var IDToConnect : String = "AAAA"
    
    @ObservedObject var CentralManager = BluetoothCentralManager()
    @ObservedObject var PeripheralManager = PeripheralCentralManager()
    
    var body: some View {
        VStack
        {
            Text("Received: \(CentralManager.BytesReceivedOfCurrentSegmentSoFar) / \(CentralManager.SegmentLength)")
            Button("Listening for Songs: \(self.CentralManager.Running.description)")
            {
                self.CentralManager.startup()
            }
            Button("Broadcast")
            {
                self.PeripheralManager.startup()
                self.showPicker = !self.showPicker
            }
            Text("Sent: \(PeripheralManager.BytesSentOfCurrentSegmentSoFar) / \(PeripheralManager.TotalBytesOfCurrentSegment)")
        }.sheet(isPresented: self.$showPicker,
                onDismiss: self.sendSong)
            {
               SongPicker(songs: self.$songs)
            }
    }
    
    func sendSong()
    {
        if(self.songs == nil)
        {
            return
        }
        
        let songItems: [MPMediaItem] = self.songs!.items
        let songItem = songItems[0]
        
        if let url = songItem.value(forProperty: MPMediaItemPropertyAssetURL)
        {
            let asset = AVAsset(url: url as! URL)
            NSLog("Compatible exports are : \(AVAssetExportSession.exportPresets(compatibleWith: asset))")
          
            let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetLowQuality)
            session!.outputFileType = AVFileType.mp4
            AVAssetExportSession.exportPresets(compatibleWith: asset)
            
            session?.shouldOptimizeForNetworkUse = true
            session?.canPerformMultiplePassesOverSourceMediaData = true
            
            session!.outputURL = URL(fileURLWithPath: Globals.ExportedAudioFilePath.path)
            
            NSLog("Going to export to location: \(session!.outputURL!)")

            clean(path: session!.outputURL!.path)

            session?.exportAsynchronously(completionHandler:
            {
                if(session?.status == .completed)
                {
                    do
                    {
                        let data = try Data.init(contentsOf: session!.outputURL!)
                        DispatchQueue.main.async
                        {
                            self.PeripheralManager.startSend(content: data)
                        }
                    }
                    catch
                    {
                        NSLog("Could not fill buffer with data from \(session!.outputURL!) : \(error)")
                    }
                }
                else
                {
                    NSLog("Failed for \(String(describing: session?.outputURL)) status: \(String(describing: session?.status.rawValue)) \(String(describing: session?.error))")
                }
            })

        }
    }
    
    func clean(path : String)
    {
        do
        {
            if(FileManager.default.fileExists(atPath: path))
            {
                try FileManager.default.removeItem(atPath: path)
                NSLog("Deleted old file at \(path)")
            }
            
        }
        catch
        {
            NSLog("Failed to remove file at \(path) : \(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

