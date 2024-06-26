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
    
    var tileFetcher: TileFetcher = TileFetcher()
    
    private var cancellables = Set<AnyCancellable>()

    let locationManager = LocationDataManager()
    
    let maxWidth = Int(bounds.width);
    let maxHeight = Int(bounds.height);
    
    private var centerMeters = proj.LatlonToMeters(latlon: defaultLatLon)
    private var locationMeters = proj.LatlonToMeters(latlon: defaultLatLon)
    
    @Published var tiles: [TileKey:Tile] = [:]
    @Published var tile: Tile =
    Tile(
        tilepos: proj.toGoogleTilepos(
            tilepos: proj.MetersToTilepos(
                meters: proj.LatlonToMeters(latlon: defaultLatLon),
                zoom: defaultZoom),
            zoom: defaultZoom),
        z: defaultZoom)

    @Published var zoomC: CGFloat = CGFloat(defaultZoom)
    
    @Published var initialTx: Int = .zero
    @Published var initialTy: Int = .zero
    
    @Published var offsetX: CGFloat = .zero
    @Published var offsetY: CGFloat = .zero
    @Published var panOffsetX: CGFloat = .zero
    @Published var panOffsetY: CGFloat = .zero
    
    @Published var dotOffsetX: CGFloat = .zero
    @Published var dotOffsetY: CGFloat = .zero
    
    @AppStorage("nightModeSetting") var nightModeSetting: Bool = false
    @AppStorage("crosshairSetting") var crosshairSetting: Bool = false
    @AppStorage("hapticFeedbackSetting") var hapticFeedbackSetting: Bool = true
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
        listenForImages()
        listenForCoordinates()
        locationManager.requestLocation()
    }
    
    
    func scale() -> CGFloat {
        let fraction = (zoomC - CGFloat(Int(zoomC)))
        let s = 1 + fraction
        return s
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
        
        // clear tiles that may be from other layer
        self.tiles.removeAll()
        
        Task { await self.loadTiles() }
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
    
    func listenForImages() {
        tileFetcher.images
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] tileKey in
                guard let self = self else { return }
                guard let tile = self.tiles[tileKey] else { return }
                #if false
                print("got \(tile.id)")
                #endif
                let image = self.tileFetcher.cache.get(url: layer.url(tileKey: tileKey))
                self.tiles.updateValue(tile.withImage(image: image!), forKey: tile.id)
            })
            .store(in: &cancellables)
    }
    
    func listenForCoordinates() {
        locationManager.$currentLocation
            .sink { [weak self] loc in
                guard let self = self else { return }
                guard let coord = loc?.coordinate else { return }
                let latlon = Latlon(lat: coord.latitude, lon: coord.longitude)
                self.locationMeters = proj.LatlonToMeters(latlon: latlon)
                if (self.followOverridden) {
                    let centerPixels = proj.MetersToPixels(meters: centerMeters, zoom: Int(zoomC))
                    self.setDotOffset(newCenterPixels: centerPixels)
                }
                else {
                    self.zoomTo(newCenterMeters: locationMeters)
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
    
    // Pan offset is measured by finger movement
    //          +
    //          |
    //          |
    //  +-------+-------> by.translation.width
    //          |
    //          |
    //          v
    // by.translation.height
    func handlePan(by: CGSize) {
        if (following) {
            followOverridden = true
        }
        
        // view moves left/west,  map moves right => panOffsetX < 0
        // view moves right/east, map moves left  => panOffsetX > 0
        self.panOffsetX = by.width
        // view moves down/south, map moves up    => panOffsetY < 0
        // view moves up/north,   map moves down  => panOffsetY > 0
        self.panOffsetY = by.height
        
        #if false
        print("panOffset \(panOffsetX),\(panOffsetY)")
        #endif
        
        let (_, newCenterMeters) = self.calculateNewCenterMeters(
            centerMeters: self.centerMeters,
            panOffsetX: self.panOffsetX,
            panOffsetY: self.panOffsetY
        )
        self.tile = self.tileForMeters(meters: newCenterMeters)
        
        Task { await self.loadTiles() }
    }

    func commitPan() {
        #if DEBUG
        print("commit pan \(panOffsetX),\(panOffsetY)")
        #endif
        
        // keep the panOffset statically, scaled down, so
        // offsetX * scale() and offsetY * scale() is still
        // the same when centerX() and centerY() is calculated
        // afterwards
        self.offsetX += panOffsetX / scale()
        self.offsetY += panOffsetY / scale()
        
        let (_, newCenterMeters) = self.calculateNewCenterMeters(
            centerMeters: self.centerMeters,
            panOffsetX: self.panOffsetX,
            panOffsetY: self.panOffsetY
        )
        
        self.panOffsetX = .zero
        self.panOffsetY = .zero
        
        self.tile = self.tileForMeters(meters: newCenterMeters)
        self.centerMeters = newCenterMeters
        
        #if DEBUG
        print("center meters (after pan) @ \(centerMeters)")
        #endif
    }
    
    // Pixels are mesured from left, bottom
    //  y
    //  ^
    //  |    /
    //  |   /
    //  |  /
    //  | /
    //  +-----> x
    // 0,0
    func calculateNewCenterMeters(
        centerMeters: Meters,
        panOffsetX: CGFloat,
        panOffsetY: CGFloat
    ) -> (Pixels, Meters) {
        // pixels are measured from left,bottom => 0,0
        
        let zoom = Int(zoomC)
        
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
        print("pixels was \(oldPixels)")
        print("meters was \(locationMeters)")
        #endif
        
        let newCenterPixels = Pixels(
            // drag towards right should decrease pixels.px => panOffsetX is positive
            px: oldCenterPixels.px - panOffsetX / scale(),
            // drag towards top should decrease pixels.py => panOffsetY is negative
            py: oldCenterPixels.py + panOffsetY / scale()
        )
        let newCenterMeters = proj.PixelsToMeters(pixels: newCenterPixels, zoom: zoom)
        
        #if false
        print("pixels are \(newCenterPixels)")
        print("meters are \(newCenterMeters)")
        #endif
        
        return (newCenterPixels, newCenterMeters)
    }
    
    func setDotOffset(newCenterPixels: Pixels) {
        let zoom = Int(zoomC)
        let dotLocationPixels = proj.MetersToPixels(meters: locationMeters, zoom: zoom)
        let dotCenterOffsetX = newCenterPixels.px - dotLocationPixels.px
        let dotCenterOffsetY = newCenterPixels.py - dotLocationPixels.py
        //print("dot offset \(dotCenterOffsetX),\(dotCenterOffsetY)")
        self.dotOffsetX = offsetX + dotCenterOffsetX
        self.dotOffsetY = offsetY - dotCenterOffsetY
        //print("dot offset \(dotOffsetX),\(dotOffsetY)")
    }
    
    func centerX() -> CGFloat {
        offsetX * scale() + panOffsetX + CGFloat(maxWidth / 2)
    }
    
    func centerY() -> CGFloat {
        offsetY * scale() + panOffsetY + CGFloat(maxHeight / 2)
    }
    
    func dotX() -> CGFloat {
        centerX() - dotOffsetX * scale()
    }
    
    func dotY() -> CGFloat {
        centerY() - dotOffsetY * scale()
    }
    
    func tileOffsetX(tile: Tile) -> CGFloat {
        (CGFloat(tile.size) * scale() + CGFloat(padding))
          * CGFloat(tile.tilepos.tx - self.initialTx)
    }
    
    func tileOffsetY(tile: Tile) -> CGFloat {
        (CGFloat(tile.size) * scale() + CGFloat(padding))
          * CGFloat(tile.tilepos.ty - self.initialTy)
    }

    func zoomIn() {
        self.zoomC = min(zoomC + 1, CGFloat(layer.zoomMax()))
        zoomToCenter()
    }
    
    func zoomToCenter() {
        zoomTo(newCenterMeters: centerMeters)
    }
    
    func zoomTo(newCenterMeters: Meters) {
        // zoom has already been set before this code is run,
        // so this code calculates how it affects the placement
        // of the tile on screen (the offset from the center)
        
        // map tile is by default rendered at screen center
        
        let oldCenterMeters = self.centerMeters
        
        // find the correct tile, that contains the meter value
        self.tile = self.tileForMeters(meters: newCenterMeters)
        self.initialTx = tile.tilepos.tx
        self.initialTy = tile.tilepos.ty
        
        let zoom = Int(zoomC)
        
        // find the center of the tile, and calculate the distance from the location
        let newTilepos = proj.MetersToTilepos(meters: newCenterMeters, zoom: zoom)
        let newTileCenterMeters = proj.TileCenterMeters(tilepos: newTilepos, zoom: zoom)
        let newTileCenterPixels = proj.MetersToPixels(meters: newTileCenterMeters, zoom: zoom)
        let newCenterPixels = proj.MetersToPixels(meters: newCenterMeters, zoom: zoom)
        
        // this is always ok as we want to offset the tile from the center
        // if zoomToPixels is to the top right of the tileCenterPixels
        // the x offset should become negative, to move the tile left along the
        // x axis, and the y offset should become positive, to move the tile down
        // along the y axis
        let centerOffsetX = newTileCenterPixels.px - newCenterPixels.px
        let centerOffsetY = newTileCenterPixels.py - newCenterPixels.py
        
        // offsetX > 0 => right
        // offsetY > 0 => down
        self.offsetX = centerOffsetX
        self.offsetY = -centerOffsetY
        
        self.centerMeters = newCenterMeters
        self.setDotOffset(newCenterPixels: newCenterPixels)
        
        #if false
        let topLeftMeters = proj.TileTopLeftMeters(tilepos: newTilepos, zoom: zoom)
        let topLeftPixels = proj.MetersToPixels(meters: topLeftMeters, zoom: zoom)
        print("tile top left: meters: \(topLeftMeters)")
        print("tile top left: pixels: \(topLeftPixels)")
        print("center: meters: \(centerMeters)")
        print("center: pixels: \(proj.MetersToPixels(meters: newCenterMeters, zoom: zoom))")
        print("center: latlon: \(proj.MetersToLatLon(meters: newCenterMeters))")
        print("moved meters: \(newCenterMeters.absSub(meters: oldCenterMeters))")
        #endif
        
        //render at center screen, without respecting position
        //self.offsetX = 0; self.offsetY = 0;
        
        Task { await self.loadTiles() }
    }
    
    func tileForMeters(meters: Meters) -> Tile {
        let zoom = Int(zoomC)
        let newTilepos = proj.MetersToTilepos(meters: meters, zoom: zoom)
        let googletilepos = proj.toGoogleTilepos(tilepos: newTilepos, zoom: zoom)
        let tile = Tile(tilepos: googletilepos, z: zoom)
        return tile
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
    
    func tileZ(z: Int) -> Tile {
        let tilepos = proj.MetersToTilepos(meters: self.centerMeters, zoom: z)
        let tile = Tile(tilepos: proj.toGoogleTilepos(tilepos: tilepos, zoom: z), z: z)
        return tile
    }
    
    func loadTiles() async {
        var tiles: [Tile] = []
        tiles.append(tileZ(z: self.tile.z - 1))
        tiles.append(tileZ(z: self.tile.z + 1))
        tiles.append(contentsOf:
            ([tile] + neighbors(tile: tile))
            .filter { t in isTileVisible(tile: t) }
        )
        for (tile) in tiles {
            let existingTileIndex = self.tiles[tile.id]
            if existingTileIndex == nil {
                self.tiles[tile.id] = tile
                Task { tileFetcher.fetchTile(layer: layer, tileKey: tile.id) }
            }
        }
        
        #if false
        print("# \(self.tiles.count)")
        #endif
        
        Task(priority: .low) {
            for (tileKey, tile) in self.tiles {
                if tile.z == self.tile.z && !isTileVisible(tile: tile) {
                    self.tiles.removeValue(forKey: tileKey)
                }
            }
        }
    }
    
    func isTileVisible(tile: Tile) -> Bool {
        // EdgeInsets(top: 55.0, leading: 2.0, bottom: 39.0, trailing: 2.0)
        
        // at top left corner of screen
        let tileX = Int(centerX() - CGFloat(tile.size)/2.0 * scale() + tileOffsetX(tile: tile))
        let tileY = Int(centerY() - CGFloat(tile.size)/2.0 * scale() + tileOffsetY(tile: tile))
        
        let tileXmax = (tileX + Int(CGFloat(tile.size) * scale())),
            tileYmax = (tileY + Int(CGFloat(tile.size) * scale()))
        
        let visible = {
            // TODO handle padding when map is rotated, needs pythagoras
            // TODO let paddingToFillGapWhenMapIsAt45DegreeAngle
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
    
    
}
