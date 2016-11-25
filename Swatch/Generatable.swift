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
    
    ///A CGPoint
    case Point(x: Float, y: Float)
    
    ///A CGPoint
    case Size(width: Float, height: Float)
    
    ///A CGRect value
    case Rect(x: Float, y: Float, width: Float, height: Float)
    
    ///UIEdgeInsets value
    case EdgeInset(top: Float, left: Float, bottom: Float, right: Float)

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
    
    ///An enum
    case Enum(type: String, name: String)
    
    ///A call to the super stylesheet
    case Call(call: String, type: String)
    
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
            assert(components.count == 2, "Not a valid font. Format: Font(\"FontName\", size)")
            return .Font(font: Rhs.Font(name: components[0], size:Float(parseNumber(components[1]))))
            
        } else if let components = argumentsFromString("color", string: string) {
            assert(components.count == 1, "Not a valid color. Format: \"#rrggbb\" or \"#rrggbbaa\"")
            return .Color(color: Rhs.Color(rgba: "#\(components[0])"))
                        
        } else if let components = argumentsFromString("image", string: string) {
            assert(components.count == 1, "Not a valid redirect. Format: Image(\"ImageName\")")
            return .Image(image: components[0])
                
        } else if let components = argumentsFromString("redirect", string: string) {
            let error = "Not a valid redirect. Format $Style.Property"
            assert(components.count == 1, error)
            return .Redirect(redirection: RhsRedirectValue(redirection: components[0], type: "Any"))
            
        } else if let components = argumentsFromString("point", string: string) {
            assert(components.count == 2, "Not a valid point. Format: Point(x, y)")
            let x = parseNumber(components[0])
            let y = parseNumber(components[1])
            return .Point(x: x, y: y)
            
        } else if let components = argumentsFromString("size", string: string) {
            assert(components.count == 2, "Not a valid size. Format: Size(width, height)")
            let w = parseNumber(components[0])
            let h = parseNumber(components[1])
            return .Size(width: w, height: h)
            
        } else if let components = argumentsFromString("rect", string: string) {
            assert(components.count == 4, "Not a valid rect. Format: Rect(x, y, width, height)")
            let x = parseNumber(components[0])
            let y = parseNumber(components[1])
            let w = parseNumber(components[2])
            let h = parseNumber(components[3])
            return .Rect(x: x, y: y, width: w, height: h)
            
        } else if let components = argumentsFromString("edgeInsets", string: string) {
            assert(components.count == 4, "Not a valid edge inset. Format: EdgeInset(top, left, bottom, right)")
            let top = parseNumber(components[0])
            let left = parseNumber(components[1])
            let bottom = parseNumber(components[2])
            let right = parseNumber(components[3])
            return .EdgeInset(top: top, left: left, bottom: bottom, right: right)
            
        } else if let components = argumentsFromString("insets", string: string) {
            assert(components.count == 4, "Not a valid edge inset. Format: EdgeInset(top, left, bottom, right)")
            let top = parseNumber(components[0])
            let left = parseNumber(components[1])
            let bottom = parseNumber(components[2])
            let right = parseNumber(components[3])
            return .EdgeInset(top: top, left: left, bottom: bottom, right: right)
            
        } else if let components = argumentsFromString("enum", string: string) {
            assert(components.count == 1, "Not a valid enum. Format: enum(Type.Value)")
            let enumComponents = components.first!.componentsSeparatedByString(".")
            assert(enumComponents.count == 2, "An enum should be expressed in the form Type.Value")
            return .Enum(type: enumComponents[0], name: enumComponents[1])
            
        } else if let components = argumentsFromString("call", string: string) {
            assert(components.count == 2, "Not a valid enum. Format: enum(Type.Value)")
            let call = components[0].stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            let type = components[1].stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            return .Call(call: call, type: type)
        }
        
        throw RhsError.MalformedRhsValue(error: "Unable to parse rhs value")
    }
    
    ///The reuturn value for this expression
    
     func returnValue() -> String {

        switch self {
        case .Scalar(_): return "CGFloat"
        case .Boolean(_): return "Bool"
        case .Font(_): return Configuration.targetOsx ? "NSFont" : "UIFont"
        case .Color(_): return Configuration.targetOsx ? "NSColor" : "UIColor"
        case .Image(_): return Configuration.targetOsx ? "NSImage" : "UIImage"
        case .Enum(let type, _): return type
        case .Redirect(let r): return r.type
        case .Point(_, _): return "CGPoint"
        case .Size(_, _): return "CGSize"
        case .Rect(_, _, _, _): return "CGRect"
        case .EdgeInset(_, _, _, _): return  Configuration.targetOsx ? "NSEdgeInsets" : "UIEdgeInsets"
        case .Hash(let hash): for (_, rhs) in hash { return rhs.returnValue() }
        case .Call(_, let type): return type
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
            
        case .Enum(let type, let name):
            return generateEnum(prefix, type: type, name: name)
            
        case .Point(let x, let y):
            return generatePoint(prefix, x: x, y: y)
            
        case .Size(let w, let h):
            return generateSize(prefix, width: w, height: h)
            
        case .Rect(let x, let y, let w, let h):
            return generateRect(prefix, x: x, y: y, width: w, height: h)
            
        case .EdgeInset(let top, let left, let bottom, let right):
            return generateEdgeInset(prefix, top: top, left: left, bottom: bottom, right: right)
            
        case .Call(let call, _):
            return generateCall(prefix, string: call)
            
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
        return "\(prefix)CGFloat(\(float))"
    }
    
    func generateBool(prefix: String, boolean: Bool) -> String {
        return "\(prefix)\(boolean)"
    }
    
    func generateFont(prefix: String, font: Rhs.Font) -> String {
        let fontClass = Configuration.targetOsx ? "NSFont" : "UIFont"
        
        //system font
        if font.isSystemBoldFont || font.isSystemFont {
            let function = font.isSystemFont ? "systemFontOfSize" : "boldSystemFontOfSize"
            let weight = font.hasWeight ? ", weight: \(font.weight!)" : ""
            return "\(prefix)\(fontClass).\(function)(\(font.fontSize)\(weight))"
        }
        
        //font with name
        return "\(prefix)\(fontClass)(name: \"\(font.fontName)\", size: \(font.fontSize))!"
    }
    
    func generateColor(prefix: String, color: Rhs.Color) -> String {
        let colorClass = Configuration.targetOsx ? "NSColor" : "UIColor"
        return "\(prefix)\(colorClass)(red: \(color.red), green: \(color.green), blue: \(color.blue), alpha: \(color.alpha))"
    }
    
    func generateImage(prefix: String, image: String) -> String {
        let colorClass = Configuration.targetOsx ? "NSImage" : "UImage"
        return "\(prefix)\(colorClass)(named: \"\(image)\")!"
    }
    
    func generateRedirection(prefix: String, redirection: RhsRedirectValue) -> String {
        if Configuration.targetOsx {
            return "\(prefix)\(redirection.redirection)Property()"
        } else {
            return "\(prefix)\(redirection.redirection)Property(traitCollection)"
        }
    }
    
    func generateEnum(prefix: String, type: String, name: String) -> String {
        return "\(prefix)\(type).\(name)"
    }
    
    func generatePoint(prefix: String, x: Float, y: Float) -> String {
        return "\(prefix)CGPoint(x: \(x), y: \(y))"
    }
    
    func generateSize(prefix: String, width: Float, height: Float) -> String {
        return "\(prefix)CGSize(width: \(width), height: \(height))"
    }

    func generateRect(prefix: String, x: Float, y: Float, width: Float, height: Float) -> String {
        return "\(prefix)CGRect(x: \(x), y: \(y), width: \(width), height: \(height))"
    }
    
    func generateEdgeInset(prefix: String, top: Float, left: Float, bottom: Float, right: Float) -> String {
        return "\(prefix)\(Configuration.targetOsx ? "NS" : "UI")EdgeInsets(top: \(top), left: \(left), bottom: \(bottom), right: \(right))"
    }
    
    func generateCall(prefix: String, string: String) -> String {
        return "\(prefix)\(string)"
    }
}

//MARK: Property

 class Property {
    
     var rhs: RhsValue
     let key: String
     var isOverride: Bool = false
     var isOverridable: Bool = false
    
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
            var visibility = "private"
            if Configuration.targetSwift3 {
                visibility = self.isOverridable ? "public" : "fileprivate"
            }
            method += "\n\t\t\(visibility) var _\(self.key): \(self.rhs.returnValue())?"
        }
        
        //options
        let objc = Configuration.objcGeneration ? "@objc " : ""
        let screen = Configuration.targetOsx ? "NSApplication.sharedApplication().mainWindow?" : (Configuration.targetSwift3 ? "UIScreen.main" : "UIScreen.mainScreen()")
        let methodArgs =  Configuration.targetOsx ? "" : "_ traitCollection: UITraitCollection? = \(screen).traitCollection"
        let override = self.isOverride ? "override " : ""
        let visibility = self.isOverridable ? "open" : "public"
        
        method += "\n\t\t\(override)\(visibility) func \(self.key)Property(\(methodArgs)) -> \(self.rhs.returnValue()) {"
        method += "\n\t\t\tif let override = _\(self.key) { return override }"
        method += "\(rhs.generate())"
        method += "\n\t\t}"
        
        if !self.isOverride {
            method += "\n\t\t\(objc)\(visibility) var \(self.key): \(self.rhs.returnValue()) {"
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
     var isOverridable = false
    
     init(name: String, properties: [Property]) {
        
        var styleName = name.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        
        //check if this could generate an extension
        let extensionPrefix = "Extension."
        if styleName.containsString(extensionPrefix) {
            styleName = styleName.stringByReplacingOccurrencesOfString(extensionPrefix, withString: "")
            self.isExtension = true
        }
        
        let openPrefix = "Open."
        if styleName.containsString(openPrefix) {
            styleName = styleName.stringByReplacingOccurrencesOfString(openPrefix, withString: "")
            self.isOverridable = true
        }
        
        //superclass defined
        if let components = Optional(styleName.componentsSeparatedByString("<")) where components.count == 2 {
            styleName = components[0].stringByReplacingOccurrencesOfString(" ", withString: "")
            self.superclassName = components[1].stringByReplacingOccurrencesOfString(" ", withString: "")
        }
        
        if self.isOverridable {
            properties.forEach({ $0.isOverridable = true })
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
        let visibility = self.isOverridable ? "open" : "public"
        wrapper += "\n\t\(objc)\(visibility) static let \(self.name) = \(self.name)AppearanceProxy()"
        wrapper += "\n\t\(objc)\(visibility) class \(self.name)AppearanceProxy\(superclass) {"
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
        
        guard let style = self.styles.filter({ return $0.name == superclass }).first else {
            
            if let components = Optional(superclass.componentsSeparatedByString(".")) where components.count == 2 {
                return true
            }
            return false
        }
        
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
        stylesheet += "\n// swiftlint:disable type_body_length\n"
        stylesheet += "// swiftlint:disable type_name\n\n"
        stylesheet += "\nimport \(importDef)\n\n"
        if let namespace = Configuration.importFrameworks {
            stylesheet += "\nimport \(namespace)\n\n"
        }
        
        if Configuration.appExtensionApiOnly {
            stylesheet += self.generateAppExtensionApplicationHeader()
        }
        
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
    
    func generateAppExtensionApplicationHeader() -> String {
        var header = ""
        header += "public class Application {\n"
        header += "\tdynamic public class func preferredContentSizeCategory() -> UIContentSizeCategory {\n"
        header += "\t\treturn .large\n"
        header += "\t}\n"
        header += "}\n\n"
        return header
    }
    
    func generateExtensionsHeader() -> String {
        let visibility = Configuration.targetSwift3 ? "fileprivate" : "private"
        var header = ""
        header += "\(visibility) var __ApperanceProxyHandle: UInt8 = 0\n\n"
        header += "///Your view should conform to 'AppearaceProxyComponent' in order to expose an appearance proxy\n"
        header += "public protocol AppearaceProxyComponent: class {\n"
        header += "\tassociatedtype ApperanceProxyType\n"
        header += "\tvar appearanceProxy: ApperanceProxyType { get }\n"
        header += "\tfunc didChangeAppearanceProxy()"
        header += "\n}\n\n"
        return header
    }
    
    func generateExtensions() -> String {
        var extensions = ""
        for style in self.styles.filter({ $0.isExtension }) {
            let visibility = Configuration.publicExtensions ? "public" : ""

            extensions += "\nextension \(style.name): AppearaceProxyComponent {\n\n"
            extensions += "\t\(visibility) typealias ApperanceProxyType = \(Configuration.stylesheetName).\(style.name)AppearanceProxy\n"
            extensions += "\t\(visibility) var appearanceProxy: ApperanceProxyType {\n"
            extensions += "\t\tget {\n"
            extensions += "\t\t\tguard let proxy = objc_getAssociatedObject(self, &__ApperanceProxyHandle) as? ApperanceProxyType else { return \(Configuration.stylesheetName).\(style.name) }\n"
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


