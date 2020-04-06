//
//  ListeningToStationView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-04.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI
import CoreBluetooth

struct ListeningToStationView: View {
    var station: Station
    
    var body: some View {
        Text("Listening to \(station.Name!)")
    }
}
