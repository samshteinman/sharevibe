//
//  ShareSongView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-02.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI
import MediaPlayer
import AVFoundation
import FileProvider
import AVKit

struct BroadcasterView: View {
    @ObservedObject var Broadcaster : CBBroadcaster = CBBroadcaster()
    
    @State private var songs : MPMediaItemCollection?
    @State private var showPicker : Bool = false
    @State private var roomName : String = ""
    
    @State private var isRoomMade = false
    
    var body: some View {
        VStack
            {
                HStack {
                    Image(systemName: "music.note")
                    TextField("Enter your station name...", text: $roomName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Image(systemName: "person.3.fill")
                    Text("\(self.Broadcaster.ListeningCentrals.count)")
                }
                .disabled(self.isRoomMade)
                .padding()
                
                Button(action: {
                    self.Broadcaster.startStation(roomName: self.roomName)
                    self.songs = nil
                    self.showPicker = !self.showPicker
                    self.isRoomMade = true
                })
                {
                    VStack {
                        Image(systemName: self.isRoomMade ? "music.note" : "antenna.radiowaves.left.and.right")
                            .font(Font.system(.largeTitle))
                            .padding()
                    }
                }
                .disabled(roomName.count == 0)
                .padding()
                
                if self.Broadcaster.startedPlayingAudio
                {
                    PlaybackControlView()
                        .padding()
                }
        }
        .sheet(isPresented: self.$showPicker,
               onDismiss: self.sendSong)
        {
            SongPickerView(songs: self.$songs)
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
            
            session!.shouldOptimizeForNetworkUse = true
            session!.canPerformMultiplePassesOverSourceMediaData = true
            
            session!.outputURL = URL(fileURLWithPath: Globals.Playback.ExportedAudioFilePath.path)
            
            NSLog("Going to export to location: \(session!.outputURL!)")
            
            clean(path: session!.outputURL!.path)
            
            session?.exportAsynchronously(completionHandler:
                {
                    if(session?.status == .completed)
                    {
                        do
                        {
                            let data = try Data.init(contentsOf: session!.outputURL!)
                            
                            DispatchQueue.main.async {
                                    self.Broadcaster.trySend(data: data)
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

struct BroadcasterView_Previews: PreviewProvider {
    static var previews: some View {
        BroadcasterView(Broadcaster: CBBroadcaster())
    }
}
