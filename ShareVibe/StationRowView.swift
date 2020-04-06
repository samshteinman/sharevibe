//
//  StationRow.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-04.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct StationRowView : View {
    var station: Station
    
    var body : some View
    {
        HStack {
            Text("\(station.Name!)")
            Spacer()
            Image(systemName: "person.3.fill")
            Text("\(station.NumberOfListeners ?? 0)")
        }.padding()
    }
}
