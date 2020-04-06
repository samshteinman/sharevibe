//
//  BufferingIndicatorView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-03.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct BufferingIndicatorView: View {
    
    @Binding var BytesReceivedSoFar : UInt64
    
    var body: some View {
            HStack
            {
                ActivityIndicatorView()
                                              
                if BytesReceivedSoFar > 0
                {
                   Text("\(Int(Double(BytesReceivedSoFar) / Double(Globals.Playback.AmountOfBytesBeforeAudioCanStart) * Double(100)))%")
                    .foregroundColor(.secondary)
                    .font(Font.system(.subheadline))
                }
            }
            .padding()
    }
}

struct BufferingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        BufferingIndicatorView(BytesReceivedSoFar: .constant(0))
    }
}
