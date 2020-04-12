//
//  StatusIndicatorView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-03.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct StatusIndicatorView: View {
    
    @Binding var Status : String
    @Binding var BufferingBytesSoFar : Int
    @Binding var MaximumBufferingBytes : Int
    @Binding var HasError : Bool
    
    var body: some View {
        VStack
            {
                HStack {
                    if !HasError
                    {
                        ActivityIndicatorView()
                            .animation(.easeOut)
                    }
                    else
                    {
                        Image(systemName: "exclamationmark.triangle")
                            .animation(.easeOut)
                            .foregroundColor(.red)
                            .font(Font.system(.largeTitle))
                    }
                    
                    Text(Status)
                        .font(Font.system(.subheadline))
                        .foregroundColor(.secondary)
                    
                    if BufferingBytesSoFar > 0 && !HasError
                    {
                        Text("\(Int(Double(BufferingBytesSoFar) / Double(MaximumBufferingBytes) * Double(100)))%")
                            .foregroundColor(.secondary)
                            .font(Font.system(.subheadline))
                    }
                }
        }
    }
}

struct StatusIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        StatusIndicatorView(Status: .constant(""), BufferingBytesSoFar: .constant(0), MaximumBufferingBytes: .constant(100), HasError: .constant(true))
    }
}
