//
//  GlobalMercator.swift
//  mtbmap Watch App
//
//  maptiler.com/tiles
//  <3 borrowed from https://github.com/datalyze-solutions/globalmaptiles/blob/master/globalmaptiles.js <3
//
//  Created by Torgeir Thoresen on 28/05/2024.
//

import Foundation

let pi = CGFloat.pi;
let pi_div_360 = pi / 360.0;
let pi_div_180 = pi / 180.0;
let pi_div_2 = pi / 2.0;
let pi_div_4 = pi / 4.0;
let pi_4 = pi * 4;
let pi_2 = pi * 2;
let _180_div_pi = 180 / pi;

struct Tilepos       { let tx:  Int, ty:  Int }
struct GoogleTilepos  { let tx:  Int, ty:  Int }
struct Latlon        { let lat: CGFloat, lon: CGFloat }
struct Meters        {
    let mx:  CGFloat;
    let my:  CGFloat
    func absSub(meters: Meters) -> Meters {
        Meters(
            mx: abs(mx - meters.mx),
            my: abs(my - meters.my)
        )
    }
}
struct Pixels        {
    let px: CGFloat;
    let py: CGFloat;
    func sub(pixels: Pixels) -> Pixels {
        Pixels(
            px: px - pixels.px,
            py: py - pixels.py
        )
    }
}

struct OverlayPath {
    let x: Int,
        y: Int,
        z: Int
}

let originShift = pi_2 * CGFloat(6378137) / CGFloat(2.0);

// Google Maps Global Mercator -- Spherical Mercator
// https://epsg.io/900913
struct GlobalMercator {
    
    let tileSize: Int
    let initialResolution: CGFloat;
    
    init(tileSize: Int) {
        self.tileSize = tileSize
        self.initialResolution = pi_2 * CGFloat(6378137) / CGFloat(tileSize);
    }
        
    func LatlonToMeters(latlon: Latlon) -> Meters {
        // Converts given lat/lon in WGS84 Datum to XY in Spherical Mercator EPSG:900913
        let mx = latlon.lon * originShift / 180.0;
        let my = log(tan((90 + latlon.lat) * pi_div_360)) / pi_div_180;
        let myShift = my * originShift / 180.0;
        return Meters(mx: mx, my: myShift);
    }

    func MetersToLatLon(meters: Meters) -> Latlon {
        // Converts XY point from Spherical Mercator EPSG:900913 to lat/lon in WGS84 Datum
        let lon = meters.mx / originShift * 180.0;
        let lat =
            _180_div_pi *
            (2 * atan(exp(meters.my / originShift * 180.0 * pi_div_180)) - pi_div_2);
        return Latlon(lat: lat, lon: lon);
    }

    func MetersToPixels(meters: Meters, zoom: Int) -> Pixels {
        // Converts EPSG:900913 to pyramid pixel coordinates in given zoom level
        let res = resolution(zoom: zoom);
        let px = (meters.mx + originShift) / res;
        let py = (meters.my + originShift) / res;
        return Pixels(px: px, py: py);
    }

    func PixelsToMeters(pixels: Pixels, zoom: Int) -> Meters {
        // Converts pixel coordinates in given zoom level of pyramid to EPSG:900913
        let res = resolution(zoom: zoom);
        let mx = pixels.px * res - originShift;
        let my = pixels.py * res - originShift;
        return Meters(mx: mx, my: my);
    }

    func resolution(zoom: Int) -> CGFloat {
        return initialResolution / pow(2, CGFloat(zoom));
    }

    func PixelsToTilepos(pixels: Pixels) -> Tilepos {
        let tx = round(ceil(pixels.px / CGFloat(tileSize)) - 1);
        let ty = round(ceil(pixels.py / CGFloat(tileSize)) - 1);
        return Tilepos(tx: Int(tx), ty: Int(ty));
    }

    func LatLonToTilepos(latlon: Latlon, zoom: Int) -> Tilepos {
        let meters = LatlonToMeters(latlon: latlon);
        let pixels = MetersToPixels(meters: meters, zoom: zoom);
        return PixelsToTilepos(pixels: pixels);
    }

    func MetersToTilepos(meters: Meters, zoom: Int) -> Tilepos {
        let pixels = MetersToPixels(meters: meters, zoom: zoom);
        return PixelsToTilepos(pixels: pixels);
    }

    func toGoogleTilepos(tilepos: Tilepos, zoom: Int) -> GoogleTilepos {
        // Converts TMS tile coordinates to Google Tile coordinates
        // coordinate origin is moved from bottom-left to top-left corner of the extent
        return GoogleTilepos(tx: tilepos.tx, ty: Int(pow(2, CGFloat(zoom))) - 1 - tilepos.ty);
    }

    func TileTopLeftMeters(tilepos: Tilepos, zoom: Int) -> Meters {
        // Returns top-left of the given tile in EPSG:900913 coordinates
        return self.PixelsToMeters(
            pixels: Pixels(
                px: CGFloat(tilepos.tx * tileSize),
                py: CGFloat(tilepos.ty * tileSize)),
            zoom: zoom
        );
    }
    
    func TileCenterMeters(tilepos: Tilepos, zoom: Int) -> Meters {
        // Returns center of the given tile in EPSG:900913 coordinates
        return self.PixelsToMeters(
            pixels: Pixels(
                px: CGFloat(tilepos.tx * tileSize + (tileSize / 2)),
                py: CGFloat(tilepos.ty * tileSize + (tileSize / 2))),
            zoom: zoom
        );
    }
    
}
