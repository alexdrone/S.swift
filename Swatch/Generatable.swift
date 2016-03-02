//
//  RhsValue.swift
//  Swatch
//
//  Created by Alex Usbergo on 19/02/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//

import Foundation

//MARK: Rhs

 enum RhsError: ErrorType {
    case MalformedRhsValue(error: String)
    case MalformedCondition(error: String)
    case Internal
}

 enum RhsValue {
    
    ///A scalar float value
    case Scalar(float: Float)
    
    ///A boolean value
    case Boolean(bool: Bool)
    
    ///A font value
    case Font(font: Rhs.Font)
    
    ///A color value
    case Color(color: Rhs.Color)
    
    ///A image
    case Image(image: String)
    
    ///A redirection to another value
    case Redirect(redirection: RhsRedirectValue)
    
    ///A map between cocndition and
    case Hash(hash: [Condition: RhsValue])
    
    private var isHash: Bool {
        switch self {
        case .Hash: return true
        default: return false
        }
    }
    
    private var isRedirect: Bool {
        switch self {
        case .Redirect: return true
        default: return false
        }
    }
    
    private var redirection: String? {
        switch self {
        case .Redirect(let r): return r.redirection
        default: return nil
        }
    }
    
    ///Returns a enum with the given payload
    
     static func valueFrom(scalar: Float) -> RhsValue  {
        return .Scalar(float: Float(scalar))
    }

     static func valueFrom(boolean: Bool) -> RhsValue  {
        return .Boolean(bool: boolean)
    }
    
     static func valueFrom(hash: [Yaml: Yaml]) throws -> RhsValue  {
        var conditions = [Condition: RhsValue]()
        for (k, value) in hash {
            
            guard let key = k.string else { continue }
            
            do {

                switch value {
                case .Int(let integer): try conditions[Condition(rawString: key)] = RhsValue.valueFrom(Float(integer))
                case .Double(let double): try conditions[Condition(rawString: key)] = RhsValue.valueFrom(Float(double))
                case .String(let string): try conditions[Condition(rawString: key)] = RhsValue.valueFrom(string)
                case .Bool(let boolean): try conditions[Condition(rawString: key)] = RhsValue.valueFrom(boolean)
                default: throw RhsError.Internal
                }
                
            } catch {
                throw RhsError.MalformedCondition(error: "\(conditions) is not well formed")
            }
        }
        return .Hash(hash: conditions)
    }
    
     static func valueFrom(string: String) throws  -> RhsValue  {
        
        if let components = argumentsFromString("font", string: string) {
            assert(components.count == 2)
            return .Font(font: Rhs.Font(name: components[0], size:Float(parseNumber(components[1]))))
            
        } else if let components = argumentsFromString("color", string: string) {
            assert(components.count == 1)
            return .Color(color: Rhs.Color(rgba: "#\(components[0])"))
                        
        } else if let components = argumentsFromString("image", string: string) {
            assert(components.count == 1)
            return .Image(image: components[0])
                
        } else if let components = argumentsFromString("redirect", string: string) {
            assert(components.count == 1)
            return .Redirect(redirection: RhsRedirectValue(redirection: components[0], type: "Any"))
        }
        
        throw RhsError.MalformedRhsValue(error: "Unable to parse rhs value")
    }
    
    ///The reuturn value for this expression
    
     func returnValue() -> String {

        switch self {
        case .Scalar(_): return "Float"
        case .Boolean(_): return "Bool"
        case .Font(_): return Configuration.targetOsx ? "NSFont" : "UIFont"
        case .Color(_): return Configuration.targetOsx ? "NSColor" : "UIColor"
        case .Image(_): return Configuration.targetOsx ? "NSImage" : "UIImage"
        case .Redirect(let r): return r.type
        case .Hash(let hash): for (_, rhs) in hash { return rhs.returnValue() }
        }
        return "AnyObject"
    }
}

 class RhsRedirectValue {
    private var redirection: String
    private var type: String
    
    init(redirection: String, type: String) {
        self.redirection = redirection
        self.type = type
    }
}

//MARK: Generator

extension RhsValue: Generatable {

     func generate() -> String {
        
        let indentation = "\n\t\t\t"
        let prefix = "\(indentation)return "
        
        switch self {
        case .Scalar(let float):
            return generateScalar(prefix, float: float)
            
        case .Boolean(let boolean):
            return generateBool(prefix, boolean: boolean)
            
        case .Font(let font):
            return generateFont(prefix, font: font)
            
        case .Color(let color):
            return generateColor(prefix, color: color)
            
        case .Image(let image):
            return generateImage(prefix, image: image)

        case .Redirect(let redirection):
            return generateRedirection(prefix, redirection: redirection)
            
        case .Hash(let hash):
            var string = ""
            for (condition, rhs) in hash {
                if !condition.isDefault() {
                    string += "\(indentation)if \(condition.generate()) { \(rhs.generate())\(indentation)}"
                }
            }
            //default should be the last condition
            for (condition, rhs) in hash {
                if condition.isDefault() {
                    string += "\(indentation)\(rhs.generate())"
                }
            }
            return string
        }        
    }
    
    func generateScalar(prefix: String, float: Float) -> String {
        return "\(prefix)Float(\(float))"
    }
    
    func generateBool(prefix: String, boolean: Bool) -> String {
        return "\(prefix)\(boolean)"
    }
    
    func generateFont(prefix: String, font: Rhs.Font) -> String {
        let fontClass = Configuration.targetOsx ? "NSFont" : "UIFont"
        
        //system font
        if font.isSystemBoldFont || font.isSystemFont {
            let function = font.isSystemFont ? "systemFontOfSize" : "boldSystemFontOfSize"
            return "\(prefix)\(fontClass).\(function)(\(font.fontSize))"
        }
        
        //font with name
        return "\(prefix)\(fontClass)(name: \(font.fontName), size: \(font.fontSize))!"
    }
    
    func generateColor(prefix: String, color: Rhs.Color) -> String {
        let colorClass = Configuration.targetOsx ? "NSColor" : "UIColor"
        return "\(prefix)\(colorClass)(red: \(color.red), green: \(color.green), blue: \(color.blue), alpha: \(color.alpha))"
    }
    
    func generateImage(prefix: String, image: String) -> String {
        let colorClass = Configuration.targetOsx ? "NSImage" : "UImage"
        return "\(prefix)\(colorClass)(named: \"\(image)\")"
    }
    
    func generateRedirection(prefix: String, redirection: RhsRedirectValue) -> String {
        if Configuration.targetOsx {
            return "\(prefix)\(redirection.redirection)Property()"
        } else {
            return "\(prefix)\(redirection.redirection)Property(traitCollection)"
        }
    }
    
}

//MARK: Property

 class Property {
    
     var rhs: RhsValue
     let key: String
     var isOverride: Bool = false
    
     init(key: String, rhs: RhsValue) {
        self.rhs = rhs
        self.key = key
    }
}

extension Property: Generatable {
    
     func generate() -> String {
        var method = ""
        method += "\n\n\t\t//MARK: \(self.key) "
        if !self.isOverride {
            method += "\n\t\tprivate var _\(self.key): \(self.rhs.returnValue())?"
        }
        
        //options
        let objc = Configuration.objcGeneration ? "@objc " : ""
        let methodArgs =  Configuration.targetOsx ? "" : "traitCollection: UITraitCollection? = UIScreen.mainScreen().traitCollection"
        let methodPublic = self.rhs.isHash ? "public" : "private"
        let override = self.isOverride ? "override " : ""
        
        method += "\n\t\t\(override)\(methodPublic) func \(self.key)Property(\(methodArgs)) -> \(self.rhs.returnValue()) {"
        method += "\n\t\t\tif let override = _\(self.key) { return override }"
        method += "\(rhs.generate())"
        method += "\n\t\t}"
        
        if !self.isOverride {
            method += "\n\t\t\(objc)public var \(self.key): \(self.rhs.returnValue()) {"
            method += "\n\t\t\tget { return self.\(self.key)Property() }"
            method += "\n\t\t\tset { _\(self.key) = newValue }"
            method += "\n\t\t}"
        }
        return method
    }
}

//MARK: Style

 class Style {
    
     let name: String
     var superclassName: String? = nil
     let properties: [Property]
     var isExtension = false
    
     init(name: String, properties: [Property]) {
        
        var styleName = name.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        
        //check if this could generate an extension
        let extensionPrefix = "Extension."
        if styleName.containsString(extensionPrefix) {
            styleName = styleName.stringByReplacingOccurrencesOfString(extensionPrefix, withString: "")
            self.isExtension = true
        }
        
        //superclass defined
        if let components = Optional(styleName.componentsSeparatedByString("<")) where components.count == 2 {
            styleName = components[0].stringByReplacingOccurrencesOfString(" ", withString: "")
            self.superclassName = components[1].stringByReplacingOccurrencesOfString(" ", withString: "")
        }
        
        self.name = styleName
        self.properties = properties
    }
}

extension Style: Generatable {
    
     func generate() -> String {
        var wrapper = ""
        wrapper += "//MARK: - \(self.name)"
        let objc = Configuration.objcGeneration ? "@objc " : ""
        var superclass = Configuration.objcGeneration ? ": NSObject" : ""
        if let s = self.superclassName { superclass = ": \(s)AppearanceProxy" }
        wrapper += "\n\t\(objc)public static let \(self.name) = \(self.name)AppearanceProxy()"
        wrapper += "\n\t\(objc)public class \(self.name)AppearanceProxy\(superclass) {"
        for property in self.properties {
            wrapper += property.generate()
        }
        wrapper += "\n\t}\n"
        return wrapper
    }
}

//MARK: Stylesheet

 class Stylesheet {
    
     let name: String
     let styles: [Style]
    
     init(name: String, styles: [Style]) {
        
        self.name = name
        self.styles = styles
        
        //resolve the type for the redirected values
        for style in styles {
            for property in style.properties {
                if property.rhs.isRedirect {
                    let redirection = property.rhs.redirection!
                    let type = self.resolveRedirectedType(redirection)
                    property.rhs = RhsValue.Redirect(redirection: RhsRedirectValue(redirection: redirection, type: type))
                }
            }
        }
        
        //mark the overrides
        for style in styles.filter({ return $0.superclassName != nil }) {
            for property in style.properties {
                property.isOverride = self.propertyIsOverride(property.key, superclass: style.superclassName!)
            }
        }
        
    }
    
    //determines if this property is an override or not
    private func propertyIsOverride(property: String, superclass: String) -> Bool {
        let style = self.styles.filter() { return $0.name == superclass}.first!
        if let _ = style.properties.filter({ return $0.key == property }).first {
            return true
        } else {
            if let s = style.superclassName {
                return self.propertyIsOverride(property, superclass: s)
            } else {
                return false
            }
        }
    }
    
    //Recursively resolves the return type for this redirected property
    private func resolveRedirectedType(redirection: String) -> String {
        
        let components = redirection.componentsSeparatedByString(".")
        assert(components.count == 2, "Redirect \(redirection) invalid")
        
        let style = self.styles.filter() { return $0.name == components[0]}.first!
        let property = style.properties.filter() { return $0.key == components[1] }.first!
        
        if property.rhs.isRedirect {
            return self.resolveRedirectedType(property.rhs.redirection!)
        } else {
            return property.rhs.returnValue()
        }
    }
}

extension Stylesheet: Generatable {

     func generate() -> String {
        var stylesheet = ""
        
        let objc = Configuration.objcGeneration ? "@objc " : ""
        let superclass = Configuration.objcGeneration ? ": NSObject" : ""
        let importDef = Configuration.targetOsx ? "Cocoa" : "UIKit"
        
        stylesheet += "///Autogenerated file\n"
        stylesheet += "\nimport \(importDef)\n\n"
        
        if Configuration.extensionsEnabled {
            stylesheet += self.generateExtensionsHeader()
        }
        
        stylesheet += "///Entry point for the app stylesheet\n"
        stylesheet += "\(objc)public class \(self.name)\(superclass) {\n\n"
        for style in self.styles {
            stylesheet += style.generate()
        }
        stylesheet += "\n}"
        
        if Configuration.extensionsEnabled {
            stylesheet += self.generateExtensions()
        }
        
        return stylesheet
    }
    
    func generateExtensionsHeader() -> String {
        var header = ""
        header += "private var __ApperanceProxyHandle: UInt8 = 0\n\n"
        header += "///Your view should conform to 'AppearaceProxyComponent' in order to expose an appearance proxy\n"
        header += "public protocol AppearaceProxyComponent: class {\n"
        header += "\ttypealias ApperanceProxyType\n"
        header += "\tvar appearanceProxy: ApperanceProxyType { get }\n"
        header += "\tfunc didChangeAppearanceProxy()"
        header += "\n}\n\n"
        header += "extension AppearaceProxyComponent {\n"
        header += "\tfunc didChangeAppearanceProxy() { print(\"\\(__FUNCTION__) not implemented in \\(self.dynamicType)\") }"
        header += "\n}\n\n"

        return header
    }
    
    func generateExtensions() -> String {
        var extensions = ""
        for style in self.styles.filter({ $0.isExtension }) {
            let visibility = Configuration.publicExtensions ? "public" : ""
            extensions += "\nextension \(style.name): AppearaceProxyComponent {\n\n"
            extensions += "\t\(visibility) typealias ApperanceProxyType = S.\(style.name)AppearanceProxy\n"
            extensions += "\t\(visibility) var appearanceProxy: ApperanceProxyType {\n"
            extensions += "\t\tget {\n"
            extensions += "\t\t\tguard let proxy = objc_getAssociatedObject(self, &__ApperanceProxyHandle) as? ApperanceProxyType else { return S.\(style.name) }\n"
            extensions += "\t\t\treturn proxy\n"
            extensions += "\t\t}\n"
            extensions += "\t\tset {\n"
            extensions += "\t\t\tobjc_setAssociatedObject(self, &__ApperanceProxyHandle, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)\n"
            extensions += "\t\t\tdidChangeAppearanceProxy()\n"
            extensions += "\t\t}\n"
            extensions += "\t}\n"
            extensions += "}\n\n"
        }
        
        return extensions
    }
    
    
    

}


