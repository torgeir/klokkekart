//
//  ContentView.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 25/05/2024.
//
import SwiftUI
import MapKit

let centerX = WKInterfaceDevice.current().screenBounds.width/2
let centerY = WKInterfaceDevice.current().screenBounds.height/2
let maxX = WKInterfaceDevice.current().screenBounds.width
let maxY = WKInterfaceDevice.current().screenBounds.height

struct ContentView: View {
    
    let bounds = WKInterfaceDevice.current().screenBounds
    
    @StateObject var mapViewModel = MapViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    @State var isChooseMap = false
    
    var body: some View {
        NightMode(isOn: mapViewModel.nightModeSetting) {
            if (isChooseMap) {
                NavigationStack {
                    List {
                        NavigationLink(
                            destination:
                                SettingLayer(
                                    layers: mapViewModel.layers,
                                    customLayers: $mapViewModel.customLayersStorage,
                                    selectedLayer: { layer in
                                        mapViewModel.changeLayer(layer: layer)
                                        isChooseMap.toggle()
                                    },
                                    addLayer: { layer in
                                        mapViewModel.addLayer(layer: layer)
                                        isChooseMap.toggle()
                                    },
                                    deleteLayer: { index in
                                        mapViewModel.deleteLayer(at: index)
                                    }
                                )
                        ) {
                            VStack(alignment: .leading) {
                                Text("Map")
                                Text("\(mapViewModel.layer.id)")
                                    .font(.caption2)
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(.gray)
                            }
                        }
                        NavigationLink(
                            destination: SettingSightOffset(
                                adjustment: $mapViewModel.headingOffsetSetting
                            )
                        ) {
                            VStack(alignment: .leading) {
                                Text("Sight offset angle")
                                Text("\(mapViewModel.headingOffsetSetting, format: .number)°")
                                    .foregroundColor(.gray)
                            }
                        }
                        Toggle("Night mode", isOn: $mapViewModel.nightModeSetting)
                        NavigationLink("Terms of Use", destination: SettingTermsOfUse())
                    }
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") {
                                isChooseMap.toggle()
                            }
                        }
                    }
                }
            }
            else {
                
                ZStack {
                    GeometryReader { geometry in
                        
                        ZStack {
                            ForEach(mapViewModel.tiles, id: \.id) { tile in
                                let w = CGFloat(tile.w)
                                let h = CGFloat(tile.h)
                                
                                let x = mapViewModel.centerX() + mapViewModel.tileOffsetX(tile: tile)
                                let y = mapViewModel.centerY() + mapViewModel.tileOffsetY(tile: tile)
                                
                                if let image = tile.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .position(x: x, y: y)
                                        .frame(width: w, height: h, alignment: .center)
                                } else {
                                    tile.color
                                        .position(x: x, y: y)
                                        .frame(width: w, height: h, alignment: .center)
                                }
                            }
                            
                        }
                        .focusable()
                        .digitalCrownRotation(
                            detent: $mapViewModel.zoom,
                            from: mapViewModel.layer.zoomMin(),
                            through: mapViewModel.layer.zoomMax(),
                            by: 1,
                            sensitivity: .low,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true,
                            onChange: { value in
                                //print("crown change", value)
                            },
                            onIdle: {
                                print("zoom is \(mapViewModel.zoom)")
                                mapViewModel.zoomToCenter()
                            }
                        )
                        .onTapGesture(count: 2) { mapViewModel.zoomIn() }
                        .gesture(
                            DragGesture()
                                .onChanged { value in mapViewModel.handlePan(by: value) }
                                .onEnded { _ in mapViewModel.commitPan() })
                        .onAppear { mapViewModel.zoomToCenter() }
                        ZStack {
                            if (mapViewModel.following
                                && mapViewModel.locationManager.currentLocation != nil) {
                                if (scenePhase == .active) {
                                    ConeOfSight(amount: mapViewModel.headingPrecision)
                                        .rotationEffect(
                                            Angle(degrees: mapViewModel.heading + mapViewModel.headingOffsetSetting),
                                            anchor: .center
                                        )
                                        //.border(.yellow)
                                        .position(
                                            x: mapViewModel.dotX(),
                                            y: mapViewModel.dotY()
                                        )
                                        .frame(width: 100.0,
                                               height: 100.0,
                                               alignment: .center)
                                        
                                }
                                Dot(accuracy: mapViewModel.locationAccuracy)
                                    //.border(.green)
                                    .position(
                                        x: mapViewModel.dotX(),
                                        y: mapViewModel.dotY()
                                    )
                                    .frame(width: 100.0,
                                           height: 100.0,
                                           alignment: .center)
                                    
                            }
                        }
                    }
                    .rotationEffect(
                        Angle(degrees: mapViewModel.mapRotation()),
                        anchor: .center
                    )
                    
                    let buttonOffset = 12.0
                    VStack {
                        HStack {
                            MapArrow(
                                bg: mapViewModel.isRotatingMap() ? .black : .gray,
                                color: mapViewModel.isRotatingMap() ? Color.red : (mapViewModel.following ? .blue : .white),
                                filled: (mapViewModel.following || mapViewModel.isRotatingMap()),
                                rotation: mapViewModel.isRotatingMap() ? mapViewModel.mapRotation() : MapArrow.DefaultRotation,
                                action: {
                                    if (mapViewModel.following) {
                                        if (mapViewModel.isRotatingMap()) {
                                            mapViewModel.stopFollow()
                                            mapViewModel.stopRotateMap()
                                        }
                                        else {
                                            mapViewModel.startRotateMap()
                                        }
                                    }
                                    else {
                                        mapViewModel.follow()
                                    }
                                })
                            .border(.clear)
                            .offset(x: -buttonOffset, y: -2)
                            IconButton("close",
                                       systemName: "list.bullet",
                                       action: { isChooseMap.toggle() })
                            .border(.clear)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(x: buttonOffset, y: -2)
                        }
                    }
                    .padding(0)
                    .position(x: centerX, y: maxY - 30)
                    .frame(maxHeight: .infinity, alignment: .trailing)
                    Copyright(mapViewModel.layer.copyright())
                        .position(x: centerX, y: maxY - 8)
                        .frame(maxWidth: maxX, alignment: .trailing)
                    // TODO debug center
                    Circle()
                        .fill(.clear)
                        .frame(width: 5.0,
                               height: 5.0,
                               alignment: .center)
                }
                .frame(width: bounds.width, height: bounds.height)
                .position(x: centerX, y: centerY)
                //.border(Color.red)
                .ignoresSafeArea()
                .aspectRatio(1, contentMode: .fill)
                .onChange(of: scenePhase, initial: false) {
                    switch scenePhase {
                    case .active:
                        print("schenePhase: active")
                        if (mapViewModel.following) {
                            mapViewModel.locationManager.startListening()
                        }
                        mapViewModel.changeLocationQuery(
                            desiredAccuracy: kCLLocationAccuracyBestForNavigation,
                            distanceFilter: 10.0
                        )
                    case .inactive:
                        print("schenePhase: inactive")
                        if (mapViewModel.following) {
                            mapViewModel.locationManager.startListening()
                        }
                        mapViewModel.changeLocationQuery(
                            desiredAccuracy: kCLLocationAccuracyHundredMeters,
                            distanceFilter: 100.0
                        )
                    default:
                        print("schenePhase: background")
                        mapViewModel.locationManager.stop()
                        mapViewModel.changeLocationQuery(
                            desiredAccuracy: kCLLocationAccuracyThreeKilometers,
                            distanceFilter: 1000.0
                        )
                    }
                }
            }
        }
        .onAppear() {
            print("initial appear")
            mapViewModel.onInitialAppear()
        }
    }
}


#Preview {
    ContentView()
}

