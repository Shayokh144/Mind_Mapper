//
//  ContentView.swift
//  MindMapper
//
//  Created by S M Taher on 21/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            PrimaryButton(title: "PRIMARY BUTTON TEST", action: {})
            SecondaryButton(title: "SECONDARY BUTTON", action: {})
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
