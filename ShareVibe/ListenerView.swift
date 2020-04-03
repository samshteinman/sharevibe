//
//  ListenSongView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-02.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct ListenerView : View {
    
    @ObservedObject private var Listener = CBListener()
    
    var body: some View {
        VStack
        {
            if Listener.startedPlayingAudio
            {
                PlaybackControlsView()
            }
            else
            {
                if self.Listener.Listening
                {
                    BufferingIndicatorView(BytesReceivedSoFar: $Listener.BytesReceivedSoFar)
                }
                else
                {
                    Button(action:
                    {
                        self.Listener.startup()
                    })
                    {
                       Image(systemName: "ear")
                       .font(Font.system(.largeTitle))
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
