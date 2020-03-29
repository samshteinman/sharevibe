//
//  CentralBroadcaster.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-03-27.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CentralBroadcaster : NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, StreamDelegate
{
    @Published var Connected = false
    
    var centralManager : CBCentralManager!
    var peripheralsToCharacteristics = Dictionary<CBPeripheral,[CBCharacteristic]>()
    var peripheralsToL2CAPChannels = Dictionary<CBPeripheral,CBL2CAPChannel>()
    var peripheralsToByteSentSoFar = Dictionary<CBPeripheral,Int>() //TODO: Send than 4GB file sizes
    var outputStreamToPeripheralMap = Dictionary<Stream,CBPeripheral>()
    
    var peripherals : [CBPeripheral] = []
    
    var bytesSentSoFar : Int = 0
    
    var data : Data = Data()
    
    func startup()
    {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if(central.state == .poweredOn)
        {
            NSLog("Bluetooth on central broadcaster")
            centralManager.scanForPeripherals(withServices: [Globals.BluetoothGlobals.ServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber)
    {
        if(!peripherals.contains(peripheral))
        {
            peripherals.append(peripheral)
            peripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
      
        peripheral.discoverServices([Globals.BluetoothGlobals.ServiceUUID]);
        
        Connected = true
        NSLog("Connected to a peripheral! \(peripheral.identifier)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    {
       if let services = peripheral.services
       {
          for service in services
          {
               if(service.uuid == Globals.BluetoothGlobals.ServiceUUID)
               {
                   peripheral.discoverCharacteristics([ Globals.BluetoothGlobals.CurrentFileSegmentDataUUID, Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID], for: service)
               }
           }
       }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error:
        Error?)
    {
        peripheralsToCharacteristics[peripheral] = service.characteristics
        
        peripheral.openL2CAPChannel(CBL2CAPPSM(192)) //192
    }
    
    func startSend(data: Data)
    {
        self.data = data
        //TODO: Observer for when a new peripheral is added
        
        resetForAllPeripherals()
        
        sendLengthToAllPeripherals()
        //sendChunkToAllPeripherals()
        startSendChunksToAllPeripheralsL2CAP()
    }
    
    func resetForAllPeripherals()
    {
        for peripheral in peripherals{
            peripheralsToByteSentSoFar[peripheral] = 0
        }
    }
    func sendLengthToAllPeripherals()
    {
        for peripheral in peripherals
        {
            if let lengthChar = peripheralsToCharacteristics[peripheral]?.first(where: {$0.uuid == Globals.BluetoothGlobals.CurrentFileSegmentLengthUUID })
            {
                peripheral.writeValue(Globals.Playback.ConvertUInt32ToData(length: UInt32(self.data.count)), for: lengthChar, type: .withResponse)
                print("Sent length to peripheral \(peripheral.identifier) : length = \(self.data.count)")
            }
        }
    }
    
    func sendChunkToAllPeripherals()
    {
        while(self.bytesSentSoFar < self.data.count)
        {
            if let chunk = getChunkFromFile()
            {
                for peripheral in peripherals
                {
                    if let dataChar = peripheralsToCharacteristics[peripheral]?.first(where: {$0.uuid == Globals.BluetoothGlobals.CurrentFileSegmentDataUUID })
                    {
                        peripheral.writeValue(chunk, for: dataChar, type: .withResponse)
                        
                        var buffer = [UInt8](chunk)
                        peripheralsToL2CAPChannels[peripheral]?.outputStream.write(&buffer, maxLength: peripheral.maximumWriteValueLength(for: .withResponse))
                    }
                }
                bytesSentSoFar += chunk.count
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        if let error = error{
            print("Couldn't write value for peripheral \(peripheral.identifier) : \(error)")
        }
    }
    
    func getChunkFromFile(index: Int) -> Data?
    {
        if(index >= self.data.count)
        {
            return nil
        }
        else if(index + Globals.ChunkSize > self.data.count)
        {
            return self.data.subdata(in: index..<(self.data.count))
        }
        else
        {
            return self.data.subdata(in: index..<(index+Globals.ChunkSize))
        }
    }
    
    func getChunkFromFile() -> Data?
    {
        return getChunkFromFile(index: self.bytesSentSoFar)
    }
    
    
    //L2CAP
    
    public func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        if let error = error{
            print("Central open l2cap error: \(error)")
            
        }
        else if let channel = channel
        {
            print("Central: open L2CAPChannel success")
            peripheralsToL2CAPChannels[peripheral] = channel
            outputStreamToPeripheralMap[channel.outputStream] = peripheral
            peripheralsToL2CAPChannels[peripheral]!.outputStream.schedule(in: .current, forMode: .default)
            peripheralsToL2CAPChannels[peripheral]!.outputStream.delegate = self
            peripheralsToL2CAPChannels[peripheral]!.outputStream.open()
        }
    }
    
    func startSendChunksToAllPeripheralsL2CAP()
    {
        var someoneStillNeedsData = true
        while(someoneStillNeedsData)
        {
            for peripheral in peripherals
            {
                if let channel = peripheralsToL2CAPChannels[peripheral]
                {
                    sendChunkToStream(stream: channel.outputStream)
                }
                someoneStillNeedsData = someoneStillNeedsData || (peripheralsToByteSentSoFar[peripheral]! < self.data.count)
            }
        }
    }
    
    
    //L2CAP Streams
    
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch(eventCode)
        {
            case .openCompleted:
                print("Central stream: open STREAM completed")
                break
            case .hasSpaceAvailable:
                print("Central stream: has space available")
                break
        case .errorOccurred:
            print(aStream.streamError)
            break
            default:
                print(eventCode)
                break
        }
    }
    
    func sendChunkToStream(stream: Stream)
    {
        if((stream as! OutputStream).hasSpaceAvailable)
        {
            if let chunk = getChunkFromFile(index: peripheralsToByteSentSoFar[outputStreamToPeripheralMap[stream]!]!)
            {
                var uint8Buffer = [UInt8](chunk)
                let bytesSent = (stream as! OutputStream).write(&uint8Buffer, maxLength: chunk.count)
                print("Sent \(bytesSent) to peripheral \(outputStreamToPeripheralMap[stream]?.identifier)")
                peripheralsToByteSentSoFar[outputStreamToPeripheralMap[stream]!]! += bytesSent
            }
        }
    }
}
