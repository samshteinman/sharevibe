//
//  ListenSongView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-02.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct ListenerView : View {
    
    @ObservedObject var Listener : CBListener = CBListener()
    @State var roomName : String = ""
    
    var body: some View {
        VStack {
            
            if !Listener.Scanning
            {
                Button(action: {
                    self.Listener.startup()
                })
                {
                    Image(systemName: "ear")
                        .font(Font.system(.largeTitle))
                }
            }
            else
            {
                VStack {
                    List (Listener.fullyDiscoveredStations.values.map{$0.self}) {
                        station in
                        
                        HStack{
                            Button(action: {
                                self.Listener.startListeningToStation(id: station.id)
                            })
                            {
                                HStack
                                    {
                                        if self.Listener.currentlyListeningToStation?.id == station.id
                                        {
                                            Image(systemName: "radiowaves.left")
                                                .font(Font.system(.largeTitle))
                                                .foregroundColor(.blue)
                                        }
                                        else
                                        {
                                            Image(systemName: "music.note")
                                        }
                                        Text("\(station.Name!)")
                                        Spacer()
                                        Image(systemName: "person.3.fill")
                                        Text("\(station.NumberOfListeners ?? 0)")
                                }
                                .padding()
                            }
                            .disabled(self.Listener.currentlyListeningToStation?.id == station.id)
                            
                            if self.Listener.startedPlayingAudio
                            {
                                PlaybackControlView()
                                    .padding()
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                    .padding()
                    
                    if !Listener.startedPlayingAudio {
                        HStack {
                            Spacer()
                            
                            BufferingIndicatorView(Status: $Listener.Status)
                            
                            if Listener.BytesReceivedSoFar > 0
                            {
                                Text("\(Int(Double(Listener.BytesReceivedSoFar) / Double(Globals.Playback.AmountOfBytesBeforeAudioCanStart) * Double(100)))%")
                                    .foregroundColor(.primary)
                                    .font(Font.system(.subheadline))
                            }
                            Spacer()
                        }
                        .padding()
                    }
                    else
                    {
                        Button(action: {
                            self.Listener.restartReceivingAudio()
                            self.Listener.cancelAllConnections()
                            self.Listener.clearAllStationLists()
                            self.Listener.startScanningForStations()
                        })
                        {
                            Image(systemName: "gobackward")
                                .font(Font.system(.largeTitle))
                                .foregroundColor(.blue)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        }
    }
}

struct ListenerView_Previews: PreviewProvider {
    static var previews: some View {
        ListenerView()
    }
}
