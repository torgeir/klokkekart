//
//  SettingsLayer.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 12/06/2024.
//

import Foundation
import SwiftUI

struct LayerLabel : View {
    var layer: any Layer
    var body: some View {
        Text(layer.id)
            .scaledToFill()
        Text("\(layer.copyright())")
            .font(.caption2)
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.gray)
    }
}

let defaultNewLayerUrl = "https:///z/x/y.png"
struct SettingLayer : View {
    var layers: [any Layer]
    @Binding var customLayers: [String]
    
    var selectedLayer: (any Layer) -> Void
    var addLayer: (String) -> Void
    var deleteLayer: (Int) -> Void
    
    @State private var newLayerUrl: String = defaultNewLayerUrl
    @State private var showingModal: Bool = false
    
    private func deleteItems(at offsets: IndexSet) {
        if let first = offsets.first {
            deleteLayer(first)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layers, id: \.id) { layer in
                        Button { selectedLayer(layer) } label: { LayerLabel(layer: layer) }
                    }
                }
                Section("User defined maps") {
                    ForEach(customLayers, id: \.self) { layer in
                        let l = OsmLayer(id: layer, url: layer)
                        Button { selectedLayer(l) } label: { LayerLabel(layer: l) }
                    }
                    .onDelete(perform: deleteItems)
                    Button {
                        showingModal = true
                    } label: {
                        Text("Add OSM layer")
                    }
                    .frame(alignment: .center)
                }
                
            }
            .sheet(isPresented: $showingModal, onDismiss: {
               newLayerUrl = defaultNewLayerUrl
            }) {
                ModalView(showingModal: $showingModal, text: $newLayerUrl) { url in
                    addLayer(url)
                }
            }
            
        }.navigationTitle("Choose Map")
    }
}

struct ModalView: View {
    @Binding var showingModal: Bool
    @Binding var text: String
    var callback: (String) -> Void
    var body: some View {
        VStack {
            Text("OSM tile server url")
            Text("https://url/z/x/y.jpg")
                .foregroundStyle(.gray)
                .font(.caption2)
            TextField(text: $text, label: { Text("Type url here.") })
            HStack {
                Button("Ok") {
                    callback(text)
                    showingModal.toggle()
                }
            }
        }
    }
}
