//
//  MapViewModel.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 25/05/2024.
//

import Foundation
import SwiftUI
import Combine

let trh = Latlon(lat: 63.43031, lon: 10.39442)
let atlanterhavsvegen = Latlon(lat: 63.01065256682027, lon: 7.310695024414056)
let nidarosdomen = Latlon(lat: 63.42675542661573, lon: 10.397386651184862)
let galdhøpiggen = Latlon(lat: 61.63442902460937, lon: 8.339096413811093)
let defaultLatLon = nidarosdomen

let padding = 0,
    tileSize = 256,
    defaultZoom = 4

let proj = GlobalMercator(tileSize: tileSize)

let defaultLayers: [any Layer] = [
    // https://kartkatalog.geonorge.no/metadata/topografisk-norgeskart-cache/8f381180-1a47-4453-bee7-9a3d64843efa
    // https://kartkatalog.geonorge.no/metadata/bakgrunnskart-forenklet-cache/17e6fec4-7d45-4835-9809-7dd6ef18a757
    // https://kartkatalog.geonorge.no/metadata/topografisk-norgeskart-cache/8f381180-1a47-4453-bee7-9a3d64843efa
    // https://kartkatalog.geonorge.no/metadata/kartdata-3-cache/be121fe0-671f-4717-a628-296e91be29d0
    // https://kartkatalog.geonorge.no/metadata/vegnett-cache/b124f553-4f55-4111-bc1f-4abed634b65e
    KartverketLayer("Topographic", map: "topo", layer: "topo"),
    KartverketLayer("Grayscale", map: "topograatone", layer: "topograatone"),
    KartverketLayer("Toporaster", map: "toporaster", layer: "toporaster"),
]
    
let bounds = WKInterfaceDevice.current().screenBounds
let scale = WKInterfaceDevice.current().screenBounds

@MainActor
class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    var layer: any Layer = defaultLayers[0]
    var tileFetcher: TileFetcher = TileFetcher(layer: defaultLayers[0])
    
    private var cancellables = Set<AnyCancellable>()

    let locationManager = LocationDataManager()
    
    let maxWidth = Int(bounds.width);
    let maxHeight = Int(bounds.height);
    
    private var initialTx: Int = .zero
    private var initialTy: Int = .zero
    
    private var meters = proj.LatlonToMeters(latlon: defaultLatLon)
    
    @Published var tiles: [Tile] = []
    @Published var tile: Tile =
    Tile(
        tilepos: proj.toGoogleTilepos(
            tilepos: proj.MetersToTilepos(
                meters: proj.LatlonToMeters(latlon: defaultLatLon),
                zoom: defaultZoom),
            zoom: defaultZoom),
        z: defaultZoom)

    @Published var cache = NSCache<NSString, UIImage>()
    
    @Published var zoom: Int = defaultZoom
    
    @Published var offsetX: CGFloat = .zero
    @Published var offsetY: CGFloat = .zero
    @Published var panOffsetX: CGFloat = .zero
    @Published var panOffsetY: CGFloat = .zero
    
    @AppStorage("nightModeSetting") var nightModeSetting: Bool = false
    @AppStorage("headingOffsetSetting") var headingOffsetSetting: Double = .zero
    @AppStorage("selectedLayerIdSetting") var selectedLayerIdSetting: String = defaultLayers[0].id
    
    @AppStorageCodable(key: "customLayersSetting", defaultValue: []) var customLayersStorage: [String]
    
    @Published var layers: [any Layer] = defaultLayers
    @Published var following: Bool = false
    @Published var locationAccuracy: CLLocationAccuracy = -1
    @Published var heading: CLLocationDegrees = .zero
    @Published var headingPrecision: CLLocationDegrees = 1
    @Published var headingRotatesMap: Bool = false
    

    func onInitialAppear() {
        if let layer = 
            allLayers()
            .first(where: { layer in layer.id == selectedLayerIdSetting}) {
                changeLayer(layer: layer)
            }
        listenForCoordinates()
    }
    
    func allLayers() -> [any Layer] {
        var allLayers: [any Layer] = []
        allLayers.append(contentsOf: layers)
        allLayers.append(contentsOf: customLayersStorage.map({ url in OsmLayer(id: url, url: url)}))
        return allLayers
    }
    
    func deleteLayer(at: Int) {
        self.customLayersStorage.remove(at: at)
        self.changeLayer(layer: layers[0])
    }
    
    func addLayer(layer: String) {
        self.customLayersStorage.append(layer)
        #if DEBUG
        print("add layer \(layer)")
        #endif

        let l = OsmLayer(id: layer, url: layer);
        self.changeLayer(layer: l)
    }
    
    func changeLayer(layer: any Layer) {
        self.selectedLayerIdSetting = layer.id
        self.layer = layer
        self.tileFetcher = TileFetcher(layer: layer)
        self.loadTiles()
    }
    
    func startRotateMap() { headingRotatesMap = true }
    func stopRotateMap() { headingRotatesMap = false }
    func isRotatingMap() -> Bool { headingRotatesMap && heading != -1 }
    func mapRotation() -> Double { headingRotatesMap ? -heading : 0.0}
    
    func follow() {
        locationManager.startListening()
        following = true
    }
    
    func stopFollow() {
        locationManager.stop()
        following = false
    }
    
    func changeLocationQuery(
        desiredAccuracy: CLLocationAccuracy,
        distanceFilter: CLLocationDistance
    ) {
        locationManager.locationManager.desiredAccuracy = desiredAccuracy
        locationManager.locationManager.distanceFilter = distanceFilter
    }
    
    func listenForCoordinates() {
        locationManager.$currentLocation
            .sink { [weak self] loc in
                guard let self = self else { return }
                guard let coord = loc?.coordinate else { return }
                self.zoomTo(latlon: Latlon(lat: coord.latitude, lon: coord.longitude))
                self.locationAccuracy = loc?.horizontalAccuracy ?? -1
            }
            .store(in: &cancellables)
        
        locationManager.$currentHeading
            .sink { [weak self] heading in
                guard let self = self else { return }
                guard let heading = heading else { return }
                if (heading.headingAccuracy > 0) {
                    self.heading = heading.trueHeading
                    self.headingPrecision = heading.headingAccuracy / 360.0
                }
                else {
                    self.heading = -1
                    self.headingPrecision = -1
                }
            }
            .store(in: &cancellables)
    }

    func handlePan(by: DragGesture.Value) {
        self.stopFollow()
        self.stopRotateMap()
        self.panOffsetX = by.translation.width
        self.panOffsetY = by.translation.height
        
        // don't save meters, just calculate the current center tile
        let (tile, _) = calculateCenter(meters: meters, zoom: zoom)
        self.tile = tile
        
        loadTiles()
    }

    func commitPan() {
        #if DEBUG
        print("commit pan \(panOffsetX),\(panOffsetY)")
        #endif
        
        self.offsetX += panOffsetX
        self.offsetY += panOffsetY
        
        // save meters, as the current center has now changed
        let (tile, meters) = calculateCenter(meters: meters, zoom: zoom)
        self.tile = tile
        self.meters = meters
        #if DEBUG
        print("meters @ \(meters)")
        print("latlon @ \(proj.MetersToLatLon(meters: meters))")
        #endif

        self.panOffsetX = .zero
        self.panOffsetY = .zero
    }
    
    func calculateCenter(meters: Meters, zoom: Int) -> (Tile, Meters) {
        let oldPixels = proj.MetersToPixels(meters: meters, zoom: zoom)
        #if false
        print("pixels was \(oldPixels)")
        print("meters was \(meters)")
        #endif
        
        let pixels = Pixels(
            px: oldPixels.px - panOffsetX,
            py: oldPixels.py + panOffsetY
        )
        
        let meters = proj.PixelsToMeters(pixels: pixels, zoom: zoom)
        let newTilepos = proj.MetersToTilepos(meters: meters, zoom: zoom)
        let googletilepos = proj.toGoogleTilepos(tilepos: newTilepos, zoom: zoom)
        let tile = Tile(tilepos: googletilepos, z: zoom)
        
        #if false
        print("pixels now \(pixels)")
        print("meters now \(meters)")
        print("moved meters \(self.meters.absSub(meters: proj.PixelsToMeters(pixels: oldPixels, zoom: zoom)))")
        print("latlon now \(proj.MetersToLatLon(meters: meters))")
        #endif
        
        return (tile, meters)
    }
    
    func zoomTo(latlon: Latlon) {
        meters = proj.LatlonToMeters(latlon: latlon)
        updateZoom()
    }
    
    func zoomIn() {
        zoom = min(zoom + 1, layer.zoomMax())
        updateZoom()
    }
    
    func updateZoom() {
        self.tileFetcher.resetPreventFetchCache()
        
        // zoom has already been set before this code is run,
        // so this code calculates how it affects the placement
        // of the tile on screen (the offset from the center)
        
        let newTilepos = proj.MetersToTilepos(meters: meters, zoom: zoom)
        let googletilepos = proj.toGoogleTilepos(tilepos: newTilepos, zoom: zoom)
        let tileCenterMeters = proj.TileCenterMeters(tilepos: newTilepos, zoom: zoom)
        let tileCenterPixels = proj.MetersToPixels(meters: tileCenterMeters, zoom: zoom)
        self.tile = Tile(tilepos: googletilepos, z: zoom)
        
        self.initialTx = tile.tilepos.tx
        self.initialTy = tile.tilepos.ty
        
        let pixels = proj.MetersToPixels(meters: meters, zoom: zoom)
        let centerOffsetX = tileCenterPixels.px - pixels.px
        let centerOffsetY = tileCenterPixels.py - pixels.py
        
        self.offsetX = centerOffsetX
        self.offsetY = -centerOffsetY
        
        #if DEBUG
        print("pixels \(pixels)")
        print("pixel offset \(centerOffsetX),\(centerOffsetY)")
        print("final pixel offset \(self.offsetX),\(self.offsetY)")
        #endif
        
        //render at center screen, without respecting position
        //self.offsetX = 0; self.offsetY = 0;
        
        self.loadTiles()
    }

    func tileUrl(tile: Tile) -> NSString {
        layer.url(z: tile.z, x: tile.tilepos.tx, y: tile.tilepos.ty, tileSize: tileSize)
    }
    
    func neighbors(tile: Tile) -> [Tile] {
        [
            Tile(tilepos: GoogleTilepos(tx: tile.tilepos.tx    , ty: tile.tilepos.ty - 1), z: tile.z), // N
            Tile(tilepos: GoogleTilepos(tx: tile.tilepos.tx + 1, ty: tile.tilepos.ty - 1), z: tile.z), // NE
            Tile(tilepos: GoogleTilepos(tx: tile.tilepos.tx + 1, ty: tile.tilepos.ty    ), z: tile.z), // E
            Tile(tilepos: GoogleTilepos(tx: tile.tilepos.tx + 1, ty: tile.tilepos.ty + 1), z: tile.z), // SE
            Tile(tilepos: GoogleTilepos(tx: tile.tilepos.tx    , ty: tile.tilepos.ty + 1), z: tile.z), // S
            Tile(tilepos: GoogleTilepos(tx: tile.tilepos.tx - 1, ty: tile.tilepos.ty + 1), z: tile.z), // SW
            Tile(tilepos: GoogleTilepos(tx: tile.tilepos.tx - 1, ty: tile.tilepos.ty    ), z: tile.z), // W
            Tile(tilepos: GoogleTilepos(tx: tile.tilepos.tx - 1, ty: tile.tilepos.ty - 1), z: tile.z), // NW
        ]
    }
    
    func loadTiles() {
        self.tiles = ([tile] + neighbors(tile: tile)).filter(isTileVisible)
        self.tiles.forEach(pullImage)
        self.loadCachedImages()
        
        #if false
        print("# \(self.tiles.count)")
        #endif
    }
    
    func isTileVisible(tile: Tile) -> Bool {
        // EdgeInsets(top: 55.0, leading: 2.0, bottom: 39.0, trailing: 2.0)
        
        // at top left corner of screen
        let tileX = Int(centerX() - CGFloat(tile.w/2) + tileOffsetX(tile: tile))
        let tileY = Int(centerY() - CGFloat(tile.h/2) + tileOffsetY(tile: tile))
        
        let tileXmax = (tileX + tile.w),
            tileYmax = (tileY + tile.h)
        
        let visible = {
            if tileX > maxWidth || tileXmax < 0 {
                return false
            }
            if tileY > maxHeight || tileYmax < 0 {
                return false
            }
            return true
        }()
        
        #if false
        //print("screen(\(screenX),\(screenY),\(screenXmax),\(screenYmax))")
        print("visible tile? \(visible) :: \(tileX),\(tileY),\(tileXmax),\(tileYmax) :: \(tile)")
        #endif
        
        return visible
    }
    
    func centerX() -> CGFloat {
        offsetX + panOffsetX + CGFloat(maxWidth / 2)
    }
    
    func centerY() -> CGFloat {
        offsetY + panOffsetY + CGFloat(maxHeight / 2)
    }
    
    func tileOffsetX(tile: Tile) -> CGFloat {
        CGFloat(tile.w + padding) * CGFloat(tile.tilepos.tx - initialTx)
    }
    
    func tileOffsetY(tile: Tile) -> CGFloat {
        CGFloat(tile.h + padding) * CGFloat(tile.tilepos.ty - initialTy)
    }
    
    func loadCachedImages() {
        for (tile) in tiles {
            let url = tileUrl(tile: tile)
            if let image = cache.object(forKey: url),
               let index = tiles.firstIndex(where: {
                   $0.tilepos.tx == tile.tilepos.tx
                   && $0.tilepos.ty == tile.tilepos.ty
                   && $0.image == nil
               }) {
                tiles[index].image = image
            }
        }
    }
    
    func pullImage(tile: Tile) {
        let url = tileUrl(tile: tile)
        if cache.object(forKey: url) == nil {
            if (tileFetcher.hasFetchedTile(zoom: tile.z, x: tile.tilepos.tx, y: tile.tilepos.ty)) {
                return
            }
            tileFetcher.fetchTile(zoom: tile.z, x: tile.tilepos.tx, y: tile.tilepos.ty, tileSize: tileSize)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] image in
                    guard let self = self else { return }
                    if image != nil {
                        self.cache.setObject(image!, forKey: url)
                        self.loadCachedImages()
                    }
                }
                .store(in: &cancellables)
        }
    }
}
