//
//  Station.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-04.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI
import CoreBluetooth

struct Station : Identifiable
{
    var id : UUID
    var peripheral : CBPeripheral?
    var service : CBService?
    var NumberOfListeners : Int?
    var Name : String? //TODO: Size limit on room name
    
}
