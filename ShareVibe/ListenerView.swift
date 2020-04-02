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
    
    var body: some View {
        VStack
            {
         Text("Received: \(self.Listener.BytesReceivedOfCurrentSegmentSoFar) / \(self.Listener.SegmentLength)")
        Button("Listen")
        {
          self.Listener.startup()
        }
        }
    }
}

struct ListenSongView_Previews: PreviewProvider {
    static var previews: some View {
        ListenerView()
    }
}
