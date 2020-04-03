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
        VStack{
            ActivityIndicatorView()
                                          
            if BytesReceivedSoFar > 0
           {
               Text("Preparing: \(Int(Double(BytesReceivedSoFar) / Double(Globals.Playback.StartPlayBytes) * Double(100)))%")
                   .foregroundColor(.gray)
                Text("Please don't close the app yet...")
                    .foregroundColor(.red)
           }
        }
    }
}

struct BufferingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        BufferingIndicatorView(BytesReceivedSoFar: .constant(0))
    }
}
