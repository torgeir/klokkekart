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
let olavt = Latlon(lat: 63.43050046605153, lon: 10.39505037276272)
let atlanterhavsvegen = Latlon(lat: 63.01065256682027, lon: 7.310695024414056)
let nidarosdomen = Latlon(lat: 63.42675542661573, lon: 10.397386651184862)
// bottom left
let zeroZero = proj.MetersToLatLon(meters: proj.PixelsToMeters(pixels: Pixels(px: 0, py: 0), zoom: defaultZoom))
let defaultLatLon = olavt

let padding = 0,
    tileSize = 256,
    defaultZoom = 17

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
    
    private var centerMeters = proj.LatlonToMeters(latlon: defaultLatLon)
    private var locationMeters = proj.LatlonToMeters(latlon: defaultLatLon)
    
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
    
    @Published var dotOffsetX: CGFloat = .zero
    @Published var dotOffsetY: CGFloat = .zero
    
    @AppStorage("nightModeSetting") var nightModeSetting: Bool = false
    @AppStorage("crosshairSetting") var crosshairSetting: Bool = false
    @AppStorage("headingOffsetSetting") var headingOffsetSetting: Double = .zero
    @AppStorage("selectedLayerIdSetting") var selectedLayerIdSetting: String = defaultLayers[0].id
    
    @AppStorageCodable(key: "customLayersSetting", defaultValue: []) var customLayersStorage: [String]
    @Published var layers: [any Layer] = defaultLayers

    @Published var following: Bool = false
    @Published var followOverridden: Bool = false
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
        centerMeters = proj.LatlonToMeters(latlon: defaultLatLon)
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
        followOverridden = false
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
                let latlon = Latlon(lat: coord.latitude, lon: coord.longitude)
                self.locationMeters = proj.LatlonToMeters(latlon: latlon)
                if (self.followOverridden) {
                    self.setDotOffset(newCenterMeters: centerMeters)
                }
                else {
                    self.updateZoom(zoomToMeters: locationMeters)
                }
                
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
    
    func calculateNewCenterMeters(centerMeters: Meters) -> Meters {
        // pixels are measured from left,bottom => 0,0
        
        // don't save meters, as we have not moved,
        // just calculate the current center tile as we peak around
        let oldCenterMeters = self.centerMeters
        let oldCenterPixels = proj.MetersToPixels(meters: centerMeters, zoom: zoom)
        
        #if false
        let tilepos = proj.MetersToTilepos(meters: oldCenterMeters, zoom: zoom)
        let topLeftMeters = proj.TileTopLeftMeters(tilepos: tilepos, zoom: zoom)
        let topLeftPixels = proj.MetersToPixels(meters: topLeftMeters, zoom: zoom)
        let centerOfScreenIsAtPixelsFromTileBottomLeft =
            oldCenterPixels.sub(pixels: topLeftPixels)
        print("centerOfScreenIsAtPixelsFromTileBottomLeft \(centerOfScreenIsAtPixelsFromTileBottomLeft)")
        #endif
        #if false
        print("pixels was \(oldPixels)")
        print("meters was \(locationMeters)")
        #endif
        
        let newCenterPixels = Pixels(
            // drag towards right should decrease pixels.px => panOffsetX is positive
            px: oldCenterPixels.px - self.panOffsetX,
            // drag towards top should decrease pixels.py => panOffsetY is negative
            py: oldCenterPixels.py + self.panOffsetY
        )
        let newCenterMeters = proj.PixelsToMeters(pixels: newCenterPixels, zoom: zoom)
        
        #if DEBUG
        print("pixels are \(newCenterPixels)")
        print("meters are \(newCenterMeters)")
        #endif
        
        return newCenterMeters
    }
    
    func tileForMeters(meters: Meters) -> Tile {
        let newTilepos = proj.MetersToTilepos(meters: meters, zoom: zoom)
        let googletilepos = proj.toGoogleTilepos(tilepos: newTilepos, zoom: zoom)
        let tile = Tile(tilepos: googletilepos, z: zoom)
        return tile
    }

    func handlePan(by: DragGesture.Value) {
        if (following) {
            followOverridden = true
        } else {
            followOverridden = false
        }
        
        // view moves left/west,  map moves right => panOffsetX < 0
        // view moves right/east, map moves left  => panOffsetX > 0
        self.panOffsetX = by.translation.width
        // view moves down/south, map moves up    => panOffsetY < 0
        // view moves up/north,   map moves down  => panOffsetY > 0
        self.panOffsetY = by.translation.height
        
        #if false
        print("panOffset \(panOffsetX),\(panOffsetY)")
        #endif
        
        // TODO remove dependency of panOffsetX, panOffsetY
        let newCenterMeters = self.calculateNewCenterMeters(centerMeters: self.centerMeters)
        self.tile = self.tileForMeters(meters: newCenterMeters)
        
        self.loadTiles()
    }

    func commitPan() {
        #if DEBUG
        print("commit pan \(panOffsetX),\(panOffsetY)")
        #endif
        
        // keep the panOffset statically
        self.offsetX += panOffsetX
        self.offsetY += panOffsetY
        
        // TODO remove dependency of panOffsetX, panOffsetY
        let newCenterMeters = self.calculateNewCenterMeters(centerMeters: self.centerMeters)
        
        self.panOffsetX = .zero
        self.panOffsetY = .zero
        
        self.tile = self.tileForMeters(meters: newCenterMeters)
        self.centerMeters = newCenterMeters
        
        #if DEBUG
        print("center meters (after pan) @ \(centerMeters)")
        #endif

        self.setDotOffset(newCenterMeters: newCenterMeters)
    }
    
    func setDotOffset(newCenterMeters: Meters) {
        let newCenterPixels = proj.MetersToPixels(meters: newCenterMeters, zoom: zoom)
        let dotLocationPixels = proj.MetersToPixels(meters: locationMeters, zoom: zoom)
        let dotCenterOffsetX = newCenterPixels.px - dotLocationPixels.px
        let dotCenterOffsetY = newCenterPixels.py - dotLocationPixels.py
        //print("dot offset \(dotCenterOffsetX),\(dotCenterOffsetY)")
        self.dotOffsetX = offsetX + dotCenterOffsetX
        self.dotOffsetY = offsetY - dotCenterOffsetY
        print("dot offset \(dotOffsetX),\(dotOffsetY)")
    }
    
    func centerX() -> CGFloat {
        offsetX + panOffsetX + CGFloat(maxWidth / 2)
    }
    func centerY() -> CGFloat {
        offsetY + panOffsetY + CGFloat(maxHeight / 2)
    }
    
    func dotX() -> CGFloat {
        centerX() - dotOffsetX
    }
    func dotY() -> CGFloat {
        centerY() - dotOffsetY
    }
    
    func tileOffsetX(tile: Tile) -> CGFloat {
        CGFloat(tile.w + padding) * CGFloat(tile.tilepos.tx - initialTx)
    }
    
    func tileOffsetY(tile: Tile) -> CGFloat {
        CGFloat(tile.h + padding) * CGFloat(tile.tilepos.ty - initialTy)
    }

    func zoomIn() {
        zoom = min(zoom + 1, layer.zoomMax())
        zoomToCenter()
    }
    
    func zoomToCenter() {
        updateZoom(zoomToMeters: centerMeters)
    }
    
    func updateZoom(zoomToMeters: Meters) {
        self.tileFetcher.resetPreventFetchCache()
        
        // zoom has already been set before this code is run,
        // so this code calculates how it affects the placement
        // of the tile on screen (the offset from the center)
        
        // map tile is by default rendered at screen center
        
        let oldCenterMeters = self.centerMeters
        
        // find the correct tile, that contains the meter value
        let tilepos = proj.MetersToTilepos(meters: zoomToMeters, zoom: zoom)
        let googletilepos = proj.toGoogleTilepos(tilepos: tilepos, zoom: zoom)
        self.tile = Tile(tilepos: googletilepos, z: zoom)
        
        self.initialTx = tile.tilepos.tx
        self.initialTy = tile.tilepos.ty
        
        // find the center of the tile, and calculate the distance from the location
        let tileCenterMeters = proj.TileCenterMeters(tilepos: tilepos, zoom: zoom)
        let tileCenterPixels = proj.MetersToPixels(meters: tileCenterMeters, zoom: zoom)
        let zoomToPixels = proj.MetersToPixels(meters: zoomToMeters, zoom: zoom)
        
        // this is always ok as we want to offset the tile from the center
        // if zoomToPixels is to the top right of the tileCenterPixels
        // the x offset should become negative, to move the tile left along the
        // x axis, and the y offset should become positive, to move the tile down
        // along the y axis
        let centerOffsetX = tileCenterPixels.px - zoomToPixels.px
        let centerOffsetY = tileCenterPixels.py - zoomToPixels.py
        
        // offsetX > 0 => right
        // offsetY > 0 => down
        self.offsetX = centerOffsetX
        self.offsetY = -centerOffsetY
        
        self.centerMeters = zoomToMeters
        self.setDotOffset(newCenterMeters: self.centerMeters)
        
        #if DEBUG
        let topLeftMeters = proj.TileTopLeftMeters(tilepos: tilepos, zoom: zoom)
        let topLeftPixels = proj.MetersToPixels(meters: topLeftMeters, zoom: zoom)
        print("tile top left: meters: \(topLeftMeters)")
        print("tile top left: pixels: \(topLeftPixels)")
        print("center: meters: \(centerMeters)")
        print("center: pixels: \(proj.MetersToPixels(meters: zoomToMeters, zoom: zoom))")
        print("center: latlon: \(proj.MetersToLatLon(meters: zoomToMeters))")
        print("moved meters: \(zoomToMeters.absSub(meters: oldCenterMeters))")
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
        self.tiles = ([tile] 
                      + neighbors(tile: tile)
        ).filter(isTileVisible)
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
            // TODO handle padding when map is rotated, needs pythagoras
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
