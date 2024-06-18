//
//  Layers.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 08/06/2024.
//

import Foundation

protocol Layer : Hashable, Identifiable {
    var id: String { get }
    func zoomMin() -> Int
    func zoomMax() -> Int
    func isWms() -> Bool
    func url(z: Int, x: Int, y: Int, tileSize: Int) -> NSString
    func copyright() -> String
}


struct GeonorgeLayer : Layer {
    
    let id: String
    let map: String
    let layer: String
    
    init(_ id: String, map: String, layer: String) {
        self.id = id;
        self.map = map
        self.layer = layer
    }
    
    func copyright() -> String { "© Kartverket" }
    func isWms() -> Bool { true }
    func zoomMin() -> Int { 4 }
    func zoomMax() -> Int { 20 }
    
    func xOfColumn(_ column: Int, zoom: Int) -> Double {
        let x = Double(column)
        let z = Double(zoom)
        return x / pow(2.0, z) * 360.0 - 180.0
    }
    
    func yOfRow(_ row: Int, zoom: Int) -> Double {
        let y = Double(row)
        let z = Double(zoom)
        let n = pi - pi_2 * y / pow(2.0, z)
        return 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)))
    }
    
    func mercatorXofLongitude(_ lon: Double) -> Double {
        return lon * 20037508.34 / 180.0
    }
    
    func mercatorYofLatitude(_ lat: Double) -> Double {
        var y = log(tan((90 + lat) * pi_div_360)) / (pi_div_180)
        y = y * 20037508.34 / 180.0
        return y
    }

    // https://gis.stackexchange.com/questions/34276/whats-the-difference-between-epsg4326-and-epsg900913
    //    They are not the same. EPSG:4326 refers to WGS 84 whereas EPSG:900913 refers to WGS84 Web Mercator.
    //  EPSG:4326 treats the earth as an ellipsoid while EPSG:900913 treats it as a sphere.
    //  This affects calculations done based on treating the map as a flat plane which is why your features 
    //  got plotted on the wrong places. Also, coordinate values will be totally different, EPSG:4326 has decimal
    //  degree values (-180 to 180 and -90 to 90) while EPSG:900913 has metric values (-20037508.34 to 20037508.34).
    //    EPSG:4326 uses a lat/long coordinate system. Latitudes are = 90 to -90 and Longitudes are = 180 to -180
    //  EPSG:900913 uses an x/y axis coordinate system.
    func url(z: Int, x: Int, y: Int, tileSize: Int) -> NSString {
        let longitudeLeft   = xOfColumn(x, zoom: z) // minX
        let longitudeRight  = xOfColumn(x + 1, zoom: z) // maxX
        let latitudeBottom = yOfRow(y + 1, zoom: z) // minY
        let latitudeTop    = yOfRow(y, zoom: z) // maxY
        
        let left   = mercatorXofLongitude(longitudeLeft) // minX
        let right  = mercatorXofLongitude(longitudeRight) // maxX
        let bottom = mercatorYofLatitude(latitudeBottom) // minY
        let top    = mercatorYofLatitude(latitudeTop) // maxY
        
        // https://kartkatalog.geonorge.no/metadata?text=topo&DistributionProtocols=WMS-tjeneste&area=Norge
        // Add to each base endpoint, e.g. wms.topo, to show what's available
        //   ?SERVICE=WMS&REQUEST=GetCapabilities
        // curl -s 'https://wms.geonorge.no/skwms1/wms.topo?service=WMS&request=GetCapabilities' \
        //   | yq --input-format=xml '.WMS_Capabilities.Capability[].Layer[].Name'
        let bboxParams = "bbox=\(left),\(bottom),\(right),\(top)"
        let tileParams = "crs=EPSG:900913&width=\(tileSize)&height=\(tileSize)&format=image/png"
        let geonorgeWmsParams = "service=WMS&request=GetMap&version=1.3.0"
        let url = "https://wms.geonorge.no/skwms1/\(map)?layers=\(layer)&\(geonorgeWmsParams)&\(tileParams)&\(bboxParams)"
        return url as NSString
    }

    // https://github.com/osmlab/editor-layer-index/blob/4f5183132b7a7a7ee1347a52217654410096b0c1/sources/europe/no/Kartverket-friluft.geojson?short_path=7ff44b4
}


struct KartverketLayer : Layer {
    
    let id: String
    let map: String
    let layer: String
    
    init(_ id: String, map: String, layer: String) {
        self.id = id;
        self.map = map
        self.layer = layer
    }
    
    func copyright() -> String { "© Kartverket" }
    func isWms() -> Bool { true }
    func zoomMin() -> Int { 4 }
    func zoomMax() -> Int { 19 }

    // Endpoints to query capabilities
    // - https://cache.kartverket.no/topo/v1/wmts/1.0.0/?service=WMTS&request=getcapabilities
    // - https://cache.kartverket.no/toporaster/v1/wmts/1.0.0/?service=WMTS&request=getcapabilities
    // - https://cache.kartverket.no/topograatone/v1/wmts/1.0.0/?service=WMTS&request=getcapabilities
    // Use one of two endpoints to query tiles from the wmts service
    // - "https://cache.kartverket.no/\(map)/v1/wmts/1.0.0/?service=WMTS&request=GetTile&version=1.0.0&layer=\(layer)&style=default&format=image/png&tilematrixset=googlemaps&tilematrix=\(z)&tilecol=\(x)&tilerow=\(y)"
    // - "https://cache.kartverket.no/\(map)/v1/wmts/1.0.0/default/googlemaps/\(z)/\(y)/\(x).png"
    // The style is "default", the projection is "googlemaps", taken from the getcapabilities request.
    func url(z: Int, x: Int, y: Int, tileSize: Int) -> NSString {
        return "https://cache.kartverket.no/\(map)/v1/wmts/1.0.0/default/googlemaps/\(z)/\(y)/\(x).png" as NSString
    }
}


struct OsmLayer : Layer {
    
    var id: String
    var url: String
    var maxZoom: Int = 19
    var extraCopyright: String = ""
    
    func copyright() -> String { "© OpenStreetMap contributors\(extraCopyright != "" ? "\n\(extraCopyright)" : "")" }
    func zoomMin() -> Int { 4 }
    func zoomMax() -> Int { self.maxZoom }
    func isWms() -> Bool { false }
    
    func url(z: Int, x: Int, y: Int, tileSize: Int) -> NSString {
        url.replacing(try! Regex("/z/x/y"), maxReplacements: 1, with: { _ in "/\(z)/\(x)/\(y)" })
        as NSString
    }
}
