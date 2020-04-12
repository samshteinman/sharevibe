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
                    ActivityIndicatorView()
                        .animation(.easeOut)
                    
                    Text(Status)
                        .font(Font.system(.subheadline))
                        .foregroundColor(.secondary)
                    
                    if BufferingBytesSoFar > 0
                    {
                        Text("\(Int(Double(BufferingBytesSoFar) / Double(MaximumBufferingBytes) * Double(100)))%")
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
