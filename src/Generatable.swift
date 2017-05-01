import Foundation

//MARK: Rhs

enum RhsError: Error {
  case malformedRhsValue(error: String)
  case malformedCondition(error: String)
  case `internal`
}

enum RhsValue {

  /// A scalar float value.
  case scalar(float: Float)

  /// A CGPoint.
  case point(x: Float, y: Float)

  /// A CGPoint.
  case size(width: Float, height: Float)

  /// A CGRect value.
  case rect(x: Float, y: Float, width: Float, height: Float)

  /// UIEdgeInsets value.
  case edgeInset(top: Float, left: Float, bottom: Float, right: Float)

  /// A boolean value.
  case boolean(bool: Bool)

  /// A font value.
  case font(font: Rhs.Font)

  /// A color value.
  case color(color: Rhs.Color)

  /// A image.
  case image(image: String)

  /// A redirection to another value.
  case redirect(redirection: RhsRedirectValue)

  /// A map between cocndition and a rhs.
  case hash(hash: [Condition: RhsValue])

  /// An enum.
  case `enum`(type: String, name: String)

  /// A call to the super stylesheet.
  case call(call: String, type: String)

  fileprivate var isHash: Bool {
    switch self {
    case .hash: return true
    default: return false
    }
  }

  fileprivate var isRedirect: Bool {
    switch self {
    case .redirect: return true
    default: return false
    }
  }

  fileprivate var redirection: String? {
    switch self {
    case .redirect(let r): return r.redirection
    default: return nil
    }
  }

  static func valueFrom(_ scalar: Float) -> RhsValue  {
    return .scalar(float: Float(scalar))
  }

  static func valueFrom(_ boolean: Bool) -> RhsValue  {
    return .boolean(bool: boolean)
  }

  static func valueFrom(_ hash: [Yaml: Yaml]) throws -> RhsValue  {
    var conditions = [Condition: RhsValue]()
    for (k, value) in hash {
      guard let key = k.string else { continue }
      do {
        switch value {
        case .int(let integer):
          try conditions[Condition(rawString: key)] = RhsValue.valueFrom(Float(integer))
        case .double(let double):
          try conditions[Condition(rawString: key)] = RhsValue.valueFrom(Float(double))
        case .string(let string):
          try conditions[Condition(rawString: key)] = RhsValue.valueFrom(string)
        case .bool(let boolean):
          try conditions[Condition(rawString: key)] = RhsValue.valueFrom(boolean)
        default:
          throw RhsError.internal
        }
      } catch {
        throw RhsError.malformedCondition(error: "\(conditions) is not well formed")
      }
    }
    return .hash(hash: conditions)
  }

  static func valueFrom(_ string: String) throws  -> RhsValue  {

    if let components = argumentsFromString("font", string: string) {
      assert(components.count == 2, "Not a valid font. Format: Font(\"FontName\", size)")
      return .font(font: Rhs.Font(name: components[0], size:Float(parseNumber(components[1]))))

    } else if let components = argumentsFromString("color", string: string) {
      assert(components.count == 1, "Not a valid color. Format: \"#rrggbb\" or \"#rrggbbaa\"")
      return .color(color: Rhs.Color(rgba: "#\(components[0])"))

    } else if let components = argumentsFromString("image", string: string) {
      assert(components.count == 1, "Not a valid redirect. Format: Image(\"ImageName\")")
      return .image(image: components[0])

    } else if let components = argumentsFromString("redirect", string: string) {
      let error = "Not a valid redirect. Format $Style.Property"
      assert(components.count == 1, error)
      return .redirect(redirection: RhsRedirectValue(redirection: components[0], type: "Any"))

    } else if let components = argumentsFromString("point", string: string) {
      assert(components.count == 2, "Not a valid point. Format: Point(x, y)")
      let x = parseNumber(components[0])
      let y = parseNumber(components[1])
      return .point(x: x, y: y)

    } else if let components = argumentsFromString("size", string: string) {
      assert(components.count == 2, "Not a valid size. Format: Size(width, height)")
      let w = parseNumber(components[0])
      let h = parseNumber(components[1])
      return .size(width: w, height: h)

    } else if let components = argumentsFromString("rect", string: string) {
      assert(components.count == 4, "Not a valid rect. Format: Rect(x, y, width, height)")
      let x = parseNumber(components[0])
      let y = parseNumber(components[1])
      let w = parseNumber(components[2])
      let h = parseNumber(components[3])
      return .rect(x: x, y: y, width: w, height: h)

    } else if let components = argumentsFromString("edgeInsets", string: string) {
      assert(components.count == 4, "Not a valid edge inset. Format: EdgeInset(top, left, bottom, right)")
      let top = parseNumber(components[0])
      let left = parseNumber(components[1])
      let bottom = parseNumber(components[2])
      let right = parseNumber(components[3])
      return .edgeInset(top: top, left: left, bottom: bottom, right: right)

    } else if let components = argumentsFromString("insets", string: string) {
      assert(components.count == 4, "Not a valid edge inset. Format: EdgeInset(top, left, bottom, right)")
      let top = parseNumber(components[0])
      let left = parseNumber(components[1])
      let bottom = parseNumber(components[2])
      let right = parseNumber(components[3])
      return .edgeInset(top: top, left: left, bottom: bottom, right: right)

    } else if let components = argumentsFromString("enum", string: string) {
      assert(components.count == 1, "Not a valid enum. Format: enum(Type.Value)")
      let enumComponents = components.first!.components(separatedBy: ".")
      assert(enumComponents.count == 2, "An enum should be expressed in the form Type.Value")
      return .enum(type: enumComponents[0], name: enumComponents[1])

    } else if let components = argumentsFromString("call", string: string) {
      assert(components.count == 2, "Not a valid enum. Format: enum(Type.Value)")
      let call = components[0].trimmingCharacters(in: CharacterSet.whitespaces)
      let type = components[1].trimmingCharacters(in: CharacterSet.whitespaces)
      return .call(call: call, type: type)
    }

    throw RhsError.malformedRhsValue(error: "Unable to parse rhs value")
  }

  func returnValue() -> String {
    switch self {
    case .scalar(_): return "CGFloat"
    case .boolean(_): return "Bool"
    case .font(_): return Configuration.targetOsx ? "NSFont" : "UIFont"
    case .color(_): return Configuration.targetOsx ? "NSColor" : "UIColor"
    case .image(_): return Configuration.targetOsx ? "NSImage" : "UIImage"
    case .enum(let type, _): return type
    case .redirect(let r): return r.type
    case .point(_, _): return "CGPoint"
    case .size(_, _): return "CGSize"
    case .rect(_, _, _, _): return "CGRect"
    case .edgeInset(_, _, _, _): return  Configuration.targetOsx ? "NSEdgeInsets" : "UIEdgeInsets"
    case .hash(let hash): for (_, rhs) in hash { return rhs.returnValue() }
    case .call(_, let type): return type
    }
    return "AnyObject"
  }
}

class RhsRedirectValue {
  fileprivate var redirection: String
  fileprivate var type: String
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
    case .scalar(let float):
      return generateScalar(prefix, float: float)

    case .boolean(let boolean):
      return generateBool(prefix, boolean: boolean)

    case .font(let font):
      return generateFont(prefix, font: font)

    case .color(let color):
      return generateColor(prefix, color: color)

    case .image(let image):
      return generateImage(prefix, image: image)

    case .redirect(let redirection):
      return generateRedirection(prefix, redirection: redirection)

    case .enum(let type, let name):
      return generateEnum(prefix, type: type, name: name)

    case .point(let x, let y):
      return generatePoint(prefix, x: x, y: y)

    case .size(let w, let h):
      return generateSize(prefix, width: w, height: h)

    case .rect(let x, let y, let w, let h):
      return generateRect(prefix, x: x, y: y, width: w, height: h)

    case .edgeInset(let top, let left, let bottom, let right):
      return generateEdgeInset(prefix, top: top, left: left, bottom: bottom, right: right)

    case .call(let call, _):
      return generateCall(prefix, string: call)

    case .hash(let hash):
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

  func generateScalar(_ prefix: String, float: Float) -> String {
    return "\(prefix)CGFloat(\(float))"
  }

  func generateBool(_ prefix: String, boolean: Bool) -> String {
    return "\(prefix)\(boolean)"
  }

  func generateFont(_ prefix: String, font: Rhs.Font) -> String {
    let fontClass = Configuration.targetOsx ? "NSFont" : "UIFont"

    //system font
    if font.isSystemBoldFont || font.isSystemFont {
      let function = font.isSystemFont ? "systemFont" : "boldSystemFont"
      let weight = font.hasWeight ? ", weight: \(font.weight!)" : ""
      return "\(prefix)\(fontClass).\(function)(ofSize: \(font.fontSize)\(weight))"
    }

    //font with name
    return "\(prefix)\(fontClass)(name: \"\(font.fontName)\", size: \(font.fontSize))!"
  }

  func generateColor(_ prefix: String, color: Rhs.Color) -> String {
    let colorClass = Configuration.targetOsx ? "NSColor" : "UIColor"
    return
      "\(prefix)\(colorClass)"
      + "(red: \(color.red), green: \(color.green), blue: \(color.blue), alpha: \(color.alpha))"
  }

  func generateImage(_ prefix: String, image: String) -> String {
    let colorClass = Configuration.targetOsx ? "NSImage" : "UImage"
    return "\(prefix)\(colorClass)(named: \"\(image)\")!"
  }

  func generateRedirection(_ prefix: String, redirection: RhsRedirectValue) -> String {
    if Configuration.targetOsx {
      return "\(prefix)\(redirection.redirection)Property()"
    } else {
      return "\(prefix)\(redirection.redirection)Property(traitCollection)"
    }
  }

  func generateEnum(_ prefix: String, type: String, name: String) -> String {
    return "\(prefix)\(type).\(name)"
  }

  func generatePoint(_ prefix: String, x: Float, y: Float) -> String {
    return "\(prefix)CGPoint(x: \(x), y: \(y))"
  }

  func generateSize(_ prefix: String, width: Float, height: Float) -> String {
    return "\(prefix)CGSize(width: \(width), height: \(height))"
  }

  func generateRect(_ prefix: String, x: Float, y: Float, width: Float, height: Float) -> String {
    return "\(prefix)CGRect(x: \(x), y: \(y), width: \(width), height: \(height))"
  }

  func generateEdgeInset(_ prefix: String,
                         top: Float,
                         left: Float,
                         bottom: Float,
                         right: Float) -> String {
    return
      "\(prefix)\(Configuration.targetOsx ? "NS" : "UI")EdgeInsets(top: \(top), left: \(left), "
      + "bottom: \(bottom), right: \(right))"
  }

  func generateCall(_ prefix: String, string: String) -> String {
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
    self.key = key.replacingOccurrences(of: ".", with: "_")
  }
}

extension Property: Generatable {

  func generate() -> String {
    var method = ""
    method += "\n\n\t\t//MARK: \(self.key) "
    if !isOverride {
      let visibility = isOverridable ? "public" : "fileprivate"
      method += "\n\t\t\(visibility) var _\(key): \(rhs.returnValue())?"
    }

    // Options.
    let objc = Configuration.objcGeneration ? "@objc " : ""
    let screen = Configuration.targetOsx
        ? "NSApplication.sharedApplication().mainWindow?"
        : "UIScreen.main"
    let methodArgs =  Configuration.targetOsx
        ? "" : "_ traitCollection: UITraitCollection? = \(screen).traitCollection"
    let override = isOverride ? "override " : ""
    let visibility = isOverridable ? "open" : "public"

    method +=
      "\n\t\t\(override)\(visibility) func \(key)Property(\(methodArgs)) -> \(rhs.returnValue()) {"
    method += "\n\t\t\tif let override = _\(key) { return override }"
    method += "\(rhs.generate())"
    method += "\n\t\t}"

    if !isOverride {
      method += "\n\t\t\(objc)public var \(key): \(rhs.returnValue()) {"
      method += "\n\t\t\tget { return self.\(key)Property() }"
      method += "\n\t\t\tset { _\(key) = newValue }"
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
  var isApplicable = false
  var viewClass: String = "UIView"

  init(name: String, properties: [Property]) {

    var styleName = name.trimmingCharacters(in: CharacterSet.whitespaces)

    // Check if this could generate an extension.
    let extensionPrefix = "__appearance_proxy"
    if styleName.contains(extensionPrefix) {
      styleName = styleName.replacingOccurrences(of: extensionPrefix, with: "")
      isExtension = true
    }
    let openPrefix = "__open"
    if styleName.contains(openPrefix) {
      styleName = styleName.replacingOccurrences(of: openPrefix, with: "")
      isOverridable = true
    }
    let protocolPrefix = "__style"
    if styleName.contains(protocolPrefix) {
      styleName = styleName.replacingOccurrences(of: protocolPrefix, with: "")
    }
    let applicableSelfPrefix = "for Self"
    if styleName.contains(applicableSelfPrefix) {
      styleName = styleName.replacingOccurrences(of: applicableSelfPrefix, with: "")
      isApplicable = true
    }
    // Trims spaces
    styleName = styleName.replacingOccurrences(of: " ", with: "")

    // Superclass defined.
    if let components = Optional(styleName.components(separatedBy: "for")), components.count == 2 {
      styleName = components[0].replacingOccurrences(of: " ", with: "")
      viewClass = components[1].replacingOccurrences(of: " ", with: "")
      isApplicable = true
    }

    // Superclass defined.
    if let components = Optional(styleName.components(separatedBy: "extends")), components.count == 2 {
      styleName = components[0].replacingOccurrences(of: " ", with: "")
      superclassName = components[1].replacingOccurrences(of: " ", with: "")
    }
    if isOverridable {
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
    let visibility = isOverridable ? "open" : "public"

    wrapper += "\n\t\(objc)\(visibility) static let \(name) = \(name)AppearanceProxy()"
    wrapper += "\n\t\(objc)\(visibility) class \(name)AppearanceProxy\(superclass) {"

    if isOverridable {
      wrapper += "\n\t\tpublic init() {}"
    }
    for property in properties {
      wrapper += property.generate()
    }

    if isApplicable {
      wrapper += "\n\t\tpublic func apply(view: \(isExtension ? self.name : self.viewClass)) {"
      for property in properties {
        wrapper +=
            "\n\t\t\tview.\(property.key.replacingOccurrences(of: "_", with: "."))"
            + " = self.\(property.key)"
      }
      wrapper += "\n\t\t}\n"
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
    // Resolve the type for the redirected values.
    for style in styles {
      for property in style.properties {
        if property.rhs.isRedirect {
          let redirection = property.rhs.redirection!
          let type = self.resolveRedirectedType(redirection)
          property.rhs = RhsValue.redirect(redirection:
              RhsRedirectValue(redirection: redirection, type: type))
        }
      }
    }
    // Mark the overrides.
    for style in styles.filter({ return $0.superclassName != nil }) {
      for property in style.properties {
        property.isOverride = self.propertyIsOverride(property.key,
                                                      superclass: style.superclassName!)
      }
    }
  }

  // Determines if this property is an override or not.
  fileprivate func propertyIsOverride(_ property: String, superclass: String) -> Bool {

    guard let style = self.styles.filter({ return $0.name == superclass }).first else {
      if let components = Optional(superclass.components(separatedBy: ".")), components.count == 2 {
        return true
      }
      return false
    }

    if let _ = style.properties.filter({ return $0.key == property }).first {
      return true
    } else {
      if let s = style.superclassName {
        return propertyIsOverride(property, superclass: s)
      } else {
        return false
      }
    }
  }

  // Recursively resolves the return type for this redirected property.
  fileprivate func resolveRedirectedType(_ redirection: String) -> String {

    let components = redirection.components(separatedBy: ".")
    assert(components.count == 2, "Redirect \(redirection) invalid")

    let style = styles.filter() { return $0.name == components[0]}.first!
    let property = style.properties.filter() { return $0.key == components[1] }.first!

    if property.rhs.isRedirect {
      return resolveRedirectedType(property.rhs.redirection!)
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

    stylesheet += "/// Autogenerated file\n"
    stylesheet += "\n// swiftlint:disable type_body_length\n"
    stylesheet += "// swiftlint:disable type_name\n\n"
    stylesheet += "import \(importDef)\n\n"
    if let namespace = Configuration.importFrameworks {
      stylesheet += "import \(namespace)\n\n"
    }
    if Configuration.appExtensionApiOnly {
      stylesheet += self.generateAppExtensionApplicationHeader()
    }
    if Configuration.extensionsEnabled {
      stylesheet += self.generateExtensionsHeader()
    }
    stylesheet += "/// Entry point for the app stylesheet\n"
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
    header +=
      "\tdynamic public class func preferredContentSizeCategory() -> UIContentSizeCategory {\n"
    header += "\t\treturn .large\n"
    header += "\t}\n"
    header += "}\n\n"
    return header
  }

  func generateExtensionsHeader() -> String {
    let visibility = "fileprivate"
    var header = ""
    header += "\(visibility) var __ApperanceProxyHandle: UInt8 = 0\n\n"
    header += "/// Your view should conform to 'AppearaceProxyComponent'.\n"
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
      extensions +=
        "\t\(visibility) typealias ApperanceProxyType = "
        + "\(Configuration.stylesheetName).\(style.name)AppearanceProxy\n"
      extensions += "\t\(visibility) var appearanceProxy: ApperanceProxyType {\n"
      extensions += "\t\tget {\n"
      extensions +=
        "\t\t\tguard let proxy = objc_getAssociatedObject(self, &__ApperanceProxyHandle) "
        + "as? ApperanceProxyType else { return \(Configuration.stylesheetName).\(style.name) }\n"
      extensions += "\t\t\treturn proxy\n"
      extensions += "\t\t}\n"
      extensions += "\t\tset {\n"
      extensions +=
        "\t\t\tobjc_setAssociatedObject(self, &__ApperanceProxyHandle, newValue,"
        + " .OBJC_ASSOCIATION_RETAIN_NONATOMIC)\n"
      extensions += "\t\t\tdidChangeAppearanceProxy()\n"
      extensions += "\t\t}\n"
      extensions += "\t}\n"
      extensions += "}\n"
    }
    return extensions
  }
}


