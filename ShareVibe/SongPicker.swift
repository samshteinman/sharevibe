//
//  SongPicker.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-03-15.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import Foundation
import SwiftUI
import MediaPlayer

struct SongPicker : UIViewControllerRepresentable
{
    @Binding var songs : MPMediaItemCollection?
    @Environment(\.presentationMode) var presentationMode
    
    class Coordinator : NSObject, MPMediaPickerControllerDelegate
    {
        var parent: SongPicker
        init(_ parent: SongPicker)
        {
            self.parent = parent
        }
        
        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            parent.songs = mediaItemCollection
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator
    {
        Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SongPicker>) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.delegate = context.coordinator
        picker.prompt = "Pick a song to share!"
        return picker
    }
    
    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: UIViewControllerRepresentableContext<SongPicker>) {
        
    }
}
