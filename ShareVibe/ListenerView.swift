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
    @State private var showBroadcastingStartingError = false
    
    var body: some View {
        VStack {
            
            if !Listener.Scanning
            {
                Button(action: {
                    if Globals.State == Globals.CBState.Broadcaster
                    {
                        self.showBroadcastingStartingError = true
                    }
                    else
                    {
                        self.Listener.startup()
                    }
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
                                withAnimation{
                                    HStack
                                        {
                                            if self.Listener.currentlyListeningToStation?.id == station.id
                                            {
                                                Image(systemName: "radiowaves.left")
                                                    .font(Font.system(.largeTitle))
                                                    .foregroundColor(.primary)
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
                            }
                            .disabled(self.Listener.currentlyListeningToStation?.id == station.id)
                            
                            if self.Listener.startedPlayingAudio && Globals.Playback.Player.rate != 0
                            {
                                Button(action: {
                                    self.Listener.isMuted = !self.Listener.isMuted
                                    Globals.Playback.Player.isMuted = self.Listener.isMuted
                                })
                                {
                                    Image(systemName: self.Listener.isMuted ? "speaker.fill" : "speaker.3.fill")
                                        .foregroundColor(.blue)
                                }
                                .padding()
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                    .padding()
                    
                    if !Listener.startedPlayingAudio {
                        StatusIndicatorView(Status: $Listener.Status, BufferingBytesSoFar: $Listener.BytesReceivedSoFar, MaximumBufferingBytes: .constant(Globals.Playback.AmountOfBytesBeforeAudioCanStartListener), HasError: $Listener.HasError)
                            .padding()
                    }
                }
                
                Button(action: {
                    self.Listener.restart()
                })
                {
                    Image(systemName: "gobackward.minus")
                        .font(Font.system(.largeTitle))
                        .foregroundColor(.blue)
                }
                .padding()
                Spacer()
            }
        }
        .alert(isPresented: $showBroadcastingStartingError)
        {
            Alert(title: Text(Globals.Playback.Status.pleaseRestart), message: Text(Globals.Playback.Status.broadcastMadePleaseRestart))
        }
    }
}

struct ListenerView_Previews: PreviewProvider {
    static var previews: some View {
        ListenerView()
    }
}
