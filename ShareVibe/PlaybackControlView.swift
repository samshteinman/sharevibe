//
//  PlaybackControlView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-03.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct PlaybackControlView: View {
    @State private var isPlaying = true
    
    var body: some View {
        Button(action:
        {
            self.isPlaying ? Globals.Playback.Player.pause() : Globals.Playback.Player.play()
            self.isPlaying = !self.isPlaying
            //TODO: Play/Pause is reset on tab view change, known apple bug
            //Can't use AVPLayer .rate because it can stay as 1.0 even though no audio is playing
        })
        {
         Image(systemName: self.isPlaying ? "pause.fill" : "play.fill")
                                   .font(Font.system(.largeTitle))
        }
    }
}

struct PlaybackControlView_Previews: PreviewProvider {
    static var previews: some View {
        PlaybackControlView()
    }
}
