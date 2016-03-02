//
//  UIColor+Hex.swift
//  Swatch
//
//  Created by Alex Usbergo on 20/02/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//

import Foundation

struct Rhs {
    
    enum ColorInputError : ErrorType {
        case MissingHashMarkAsPrefix, UnableToScanHexValue, MismatchedHexStringLength
    }
    
    class Color {
        
        let red: Float
        let green: Float
        let blue: Float
        let alpha: Float
        var darken: Bool? = false
        var lighten: Bool? = false
        
        init(red: Float, green: Float, blue: Float, alpha: Float) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
        
        convenience init(hex3: UInt16, alpha: Float = 1) {
            let divisor = Float(15)
            let red     = Float((hex3 & 0xF00) >> 8) / divisor
            let green   = Float((hex3 & 0x0F0) >> 4) / divisor
            let blue    = Float( hex3 & 0x00F      ) / divisor
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        }
        
        convenience init(hex4: UInt16) {
            let divisor = Float(15)
            let red     = Float((hex4 & 0xF000) >> 12) / divisor
            let green   = Float((hex4 & 0x0F00) >>  8) / divisor
            let blue    = Float((hex4 & 0x00F0) >>  4) / divisor
            let alpha   = Float( hex4 & 0x000F       ) / divisor
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        }
        
        convenience init(hex6: UInt32, alpha: Float = 1) {
            let divisor = Float(255)
            let red     = Float((hex6 & 0xFF0000) >> 16) / divisor
            let green   = Float((hex6 & 0x00FF00) >>  8) / divisor
            let blue    = Float( hex6 & 0x0000FF       ) / divisor
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        }
        
        convenience init(hex8: UInt32) {
            let divisor = Float(255)
            let red     = Float((hex8 & 0xFF000000) >> 24) / divisor
            let green   = Float((hex8 & 0x00FF0000) >> 16) / divisor
            let blue    = Float((hex8 & 0x0000FF00) >>  8) / divisor
            let alpha   = Float( hex8 & 0x000000FF       ) / divisor
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        }
        
        convenience init(rgba_throws rgba: String) throws {
            guard rgba.hasPrefix("#") else {
                throw ColorInputError.MissingHashMarkAsPrefix
            }
            
            guard let hexString: String = rgba.substringFromIndex(rgba.startIndex.advancedBy(1)),
                var   hexValue:  UInt32 = 0
                where NSScanner(string: hexString).scanHexInt(&hexValue) else {
                    throw ColorInputError.UnableToScanHexValue
            }
            
            guard hexString.characters.count  == 3
                || hexString.characters.count == 4
                || hexString.characters.count == 6
                || hexString.characters.count == 8 else {
                    throw ColorInputError.MismatchedHexStringLength
            }
            
            switch (hexString.characters.count) {
            case 3:
                self.init(hex3: UInt16(hexValue))
            case 4:
                self.init(hex4: UInt16(hexValue))
            case 6:
                self.init(hex6: hexValue)
            default:
                self.init(hex8: hexValue)
            }
        }
        
        convenience init(rgba: String) {
            try! self.init(rgba_throws: rgba)
        }
        
        func hexString(includeAlpha: Bool) -> String {
            let r: Float = self.red
            let g: Float = self.green
            let b: Float = self.blue
            let a: Float = self.alpha
            
            if (includeAlpha) {
                return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
            } else {
                return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
            }
        }
        
        var description: String {
            return self.hexString(true)
        }
        
        var debugDescription: String {
            return self.hexString(true)
        }
    }
    
    class Font {
        
        let fontName: String
        let fontSize: Float
        
        var isSystemFont: Bool {
            return self.fontName.containsString("System")
        }
        
        var isSystemBoldFont: Bool {
            return self.fontName.containsString("SystemBold")
        }
        
        init(name fontName: String, size fontSize: Float) {
            self.fontName = fontName
            self.fontSize = fontSize
        }
    }

    
}
