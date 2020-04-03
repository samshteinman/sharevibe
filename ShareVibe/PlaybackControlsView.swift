//
//  PlaybackControlsView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-03.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct PlaybackControlsView: View {
    @State var isPlaying = true
    
    var body: some View {
         VStack
            {
                Button(action:
                   {
                        if self.isPlaying
                       {
                           Globals.Playback.Player.pause()
                       }
                       else
                       {
                           Globals.Playback.Player.play()
                       }
                    self.isPlaying = !self.isPlaying
                   })
                   {
                    Image(systemName: self.isPlaying ? "pause" : "play")
                                              .font(Font.system(.largeTitle))
                   }
        }
    }
}

struct PlaybackControlsView_Previews: PreviewProvider {
    static var previews: some View {
        PlaybackControlsView()
    }
}
