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
    
    var body: some View {
        HStack
            {
                ActivityIndicatorView()
                
                Text(Status)
                    .foregroundColor(.secondary)
                    .font(Font.system(.subheadline))
                    .transition(.opacity)
        }
        .padding()
    }
}

struct BufferingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        BufferingIndicatorView(Status: .constant(""))
    }
}
