//
//  ContentView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-03-13.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var Broadcaster = CBBroadcaster()
    @ObservedObject var Listener = CBListener()
    
    var body: some View {
        TabView
        {
            BroadcasterView()
            .tabItem
            {
                Image(systemName: "music.note")
                Text("Broadcast")
            }
            
            ListenerView()
            .tabItem
            {
                Image(systemName: "ear")
                Text("Listen")
            }
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}





