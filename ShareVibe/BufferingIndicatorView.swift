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
    @Binding var BytesSentSoFar : Int
    
    var body: some View {
        HStack {
                if BytesSentSoFar > 0 {
                    Image(systemName: "exclamationmark.triangle")
                        .font(Font.system(.largeTitle))
                        .foregroundColor(.red)
                }
                else
                {
                    ActivityIndicatorView()
                }
                
                Text(Status)
                    .font(Font.system(.subheadline))
                    .transition(.opacity)
                    .foregroundColor(BytesSentSoFar > 0 ? .red : .secondary)
        }
    }
}

struct BufferingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        BufferingIndicatorView(Status: .constant(""), BytesSentSoFar: .constant(0))
    }
}
