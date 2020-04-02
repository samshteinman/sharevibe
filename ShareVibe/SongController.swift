//
//  SongController.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-01.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import Foundation
import SwiftUI
import AVKit

struct SongController: UIViewControllerRepresentable
{
          func updateUIViewController(_ playerController: AVPlayerViewController, context: Context) {
              playerController.modalPresentationStyle = .fullScreen
              playerController.player = Globals.Playback.Player
          }

          func makeUIViewController(context: Context) -> AVPlayerViewController {
              return AVPlayerViewController()
          }
}
