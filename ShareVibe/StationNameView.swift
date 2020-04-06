//
//  StationNameView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-06.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct StationNameView: View {
    @Binding var roomName : String
    @Binding var isRoomMade : Bool
    
    var body: some View {
        HStack {
            Image(systemName: "music.note")
            TextField("Enter your station name...", text: $roomName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .disabled(self.isRoomMade)
    }
}

struct StationNameView_Previews: PreviewProvider {
    static var previews: some View {
        StationNameView(roomName : .constant(""), isRoomMade: .constant(true))
    }
}
