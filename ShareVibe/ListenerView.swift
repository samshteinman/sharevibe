//
//  ListenSongView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-02.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct ListenerView : View {
    
    @ObservedObject var Listener = CBListener()
    @State var roomName : String = ""
    
    var body: some View {
        VStack {
            if !Listener.Scanning
            {
                VStack {
                    Button(action: {
                        self.Listener.startScanningForStations()
                    })
                    {
                        Image(systemName: "ear")
                            .font(Font.system(.largeTitle))
                    }
                }
            }
            else
            {
                VStack {
                    Spacer()
                    
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
                                        StationRowView(station: station)
                                }
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
                            BufferingIndicatorView(BytesReceivedSoFar: $Listener.BytesReceivedSoFar)
                            Text(Listener.Status)
                                .foregroundColor(.secondary)
                                .font(Font.system(.subheadline))
                                .transition(.opacity)
                            Spacer()
                        }
                        .padding()
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
