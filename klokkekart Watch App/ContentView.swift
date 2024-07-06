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
    
    @GestureState var dragOffset = CGSize.zero
    
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
                        Toggle("Show center", isOn: $mapViewModel.crosshairSetting)
                        Toggle("Haptic feedback", isOn: $mapViewModel.hapticFeedbackSetting)
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
                            ForEach(Array(mapViewModel.tiles.keys), id: \.self) { (tileKey: TileKey) in
                                let tile = mapViewModel.tiles[tileKey]!
                                let s = CGFloat(tile.size) * mapViewModel.scale()
                                let x = mapViewModel.centerX() + mapViewModel.tileOffsetX(tile: tile)
                                let y = mapViewModel.centerY() + mapViewModel.tileOffsetY(tile: tile)
                                
                                if let image = tile.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .position(x: x, y: y)
                                        .frame(width: s, height: s, alignment: .center)
                                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                                }
                            }
                        }
                        .focusable()
                        .digitalCrownRotation(
                            detent: $mapViewModel.zoomC,
                            from: CGFloat(mapViewModel.layer.zoomMin()),
                            through: CGFloat(mapViewModel.layer.zoomMax()),
                            by: 0.08,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: mapViewModel.hapticFeedbackSetting,
                            onChange: { value in
                                //print("crown change", value)
                                mapViewModel.zoomToCenter()
                            },
                            onIdle: {
                                print("zoom is \(mapViewModel.zoomC)")
                            }
                        )
                        .onTapGesture(count: 2) { mapViewModel.zoomIn() }
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in state = value.translation }
                                .onChanged { value in
                                    mapViewModel.handlePan(by: value.translation)
                                }
                                .onEnded { gesture in
                                    let predictedEnd = gesture.predictedEndTranslation
                                    print("prediction w:\(abs(predictedEnd.width - mapViewModel.panOffsetX))")
                                    print("prediction h:\(abs(predictedEnd.height - mapViewModel.panOffsetY))")
                                    if (abs(predictedEnd.width - mapViewModel.panOffsetX) < 50 &&
                                        abs(predictedEnd.height - mapViewModel.panOffsetY) < 50) {
                                        mapViewModel.commitPan()
                                    }
                                    else {
                                        // https://cubic-bezier.com/#.1,.9,.5,1
                                        withAnimation(Animation.timingCurve(0.1, 0.9, 0.5, 1.0, duration: 0.2)) {
                                            mapViewModel.handlePan(by: predictedEnd)
                                        } completion: {
                                            mapViewModel.commitPan()
                                        }
                                    }
                                })
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
                    
                    if mapViewModel.crosshairSetting {
                        let crosshairOpacity = 1.0
                        let crosshairColor: Color = mapViewModel.nightModeSetting ? .black : .red
                        Rectangle()
                            .strokeBorder(crosshairColor.opacity(crosshairOpacity), lineWidth: 1)
                            .frame(width: 2.0, height: 10.0, alignment: .center)
                        Rectangle()
                            .strokeBorder(crosshairColor.opacity(crosshairOpacity), lineWidth: 1)
                            .frame(width: 10.0, height: 2.0, alignment: .center)
                        // TODO remove?
                        //Circle()
                        //    .strokeBorder(crosshairColor.opacity(crosshairOpacity), lineWidth: 1)
                        //    .frame(width: 21.0, height: 21.0,alignment: .center)
                            //.overlay {
                            //    Circle()
                            //        .fill(.red.opacity(crosshairOpacity))
                            //        .frame(width: 3.0,height: 3.0, alignment: .center)
                            //}
                    }
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
                        mapViewModel.changeLocationQuery(
                            desiredAccuracy: kCLLocationAccuracyBestForNavigation,
                            distanceFilter: 10.0
                        )
                        if (mapViewModel.following) {
                            mapViewModel.locationManager.startListening()
                        }
                    case .inactive:
                        print("schenePhase: inactive")
                        mapViewModel.changeLocationQuery(
                            desiredAccuracy: kCLLocationAccuracyHundredMeters,
                            distanceFilter: 100.0
                        )
                        if (mapViewModel.following) {
                            mapViewModel.locationManager.startListening()
                        }
                    default:
                        print("schenePhase: background")
                        mapViewModel.changeLocationQuery(
                            desiredAccuracy: kCLLocationAccuracyThreeKilometers,
                            distanceFilter: 1000.0
                        )
                        mapViewModel.locationManager.stop()
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

