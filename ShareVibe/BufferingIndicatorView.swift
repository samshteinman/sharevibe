//
//  BufferingIndicatorView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-03.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct BufferingIndicatorView: View {
    
    @Binding var Status : String
    @Binding var BufferingBytesSoFar : Int
    @Binding var MaximumBufferingBytes : Int
    
    var body: some View {
        VStack
            {
                HStack {
                    ActivityIndicatorView(color: BufferingBytesSoFar > 0 ? .constant(.red) : .constant(.secondaryLabel))
                        .animation(.easeOut)
                    
                    Text(Status)
                        .font(Font.system(.subheadline))
                        .foregroundColor(BufferingBytesSoFar > 0 ? .red : .secondary)
                }
                
                if BufferingBytesSoFar > 0
                {
                    HStack
                        {
                            Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            
                            Text(Globals.Playback.Status.stayOnAppWhileSync)
                            .foregroundColor(.red)
                            .font(Font.system(.subheadline))
                            
                            Text("\(Int(Double(BufferingBytesSoFar) / Double(MaximumBufferingBytes) * Double(100)))%")
                                                     .foregroundColor(.red)
                                                     .font(Font.system(.subheadline))
                    }
                }
        }
    }
}

struct BufferingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        BufferingIndicatorView(Status: .constant(""), BufferingBytesSoFar: .constant(0), MaximumBufferingBytes: .constant(100))
    }
}
