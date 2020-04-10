//
//  ActivityIndicatorView.swift
//  ShareVibe
//
//  Created by Sam Shteinman on 2020-04-02.
//  Copyright © 2020 Sam Shteinman. All rights reserved.
//

import SwiftUI

struct ActivityIndicatorView: UIViewRepresentable {
    @Binding var color : UIColor
    
    func makeUIView(context: Context) -> UIActivityIndicatorView
    {
        var view = UIActivityIndicatorView(style: .large)
        view.color = color
        return view
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context)
    {
        uiView.color = color
        uiView.startAnimating()
    }
}
