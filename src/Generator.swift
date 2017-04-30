import Foundation

public struct Configuration {
  public static var objcGeneration = false
  public static var extensionsEnabled = false
  public static var publicExtensions = true
  public static var appExtensionApiOnly = false
  public static var targetOsx = false
  public static var singleFile: String?
  public static var importFrameworks: String?
  public static var stylesheetName: String = "S"
}

public enum GeneratorError: Error {
  case fileDoesNotExist(error: String)
  case malformedYaml(error: String)
  case illegalYamlScalarValue(error: String)
}

public protocol Generatable {
  func generate() -> String
}

public struct Generator: Generatable  {

  private var stylesheet: Stylesheet? = nil

  /// Initialise the Generator with some YAML payload.
  public init(url: URL) throws {

    // Attemps to load the file at the given url.
    var string = ""
    do {
      string = try String(contentsOf: url)
    } catch {
      throw GeneratorError.fileDoesNotExist(error: "File \(url) not found.")
    }
    string = preprocessInput(string)
    guard let yaml = try? Yaml.load(string) else {
      throw GeneratorError.malformedYaml(error: "Unable to load Yaml file.")
    }
    // All of the styles define in the file.
    var styles = [Style]()
    if case .null = yaml {
      throw GeneratorError.malformedYaml(error: "Null root object.")
    }

    guard case let .dictionary(main) = yaml else {
      throw GeneratorError.malformedYaml(error: "The root object is not a dictionary.")
    }

    for (key, values) in main {
      guard let valuesDictionary = values.dictionary, let keyString = key.string else {
        throw GeneratorError.malformedYaml(error: "Malformed style definition: \(key).")
      }
      let style = Style(name: keyString, properties: try createProperties(valuesDictionary))
      styles.append(style)
    }

    stylesheet = Stylesheet(name: Configuration.stylesheetName , styles: styles)
  }

  /// Returns the swift code for this item.
  public func generate() -> String {
    return self.stylesheet?.generate() ?? "Unable to generate stylesheet"
  }

  private func createProperties(_ dictionary: [Yaml: Yaml]) throws -> [Property] {
    var properties = [Property]()
    for (yamlKey, yamlValue) in dictionary {
      if let key = yamlKey.string {
        do {
          var rhsValue: RhsValue? = nil
          switch yamlValue {
          case .dictionary(let dictionary): rhsValue = try RhsValue.valueFrom(dictionary)
          case .bool(let boolean): rhsValue = RhsValue.valueFrom(boolean)
          case .double(let double): rhsValue = RhsValue.valueFrom(Float(double))
          case .int(let integer): rhsValue = RhsValue.valueFrom(Float(integer))
          case .string(let string): rhsValue = try RhsValue.valueFrom(string)
          default:
            throw GeneratorError.illegalYamlScalarValue(
              error: "\(yamlValue) not supported as right-hand side value")
          }
          let property = Property(key: key, rhs: rhsValue!)
          properties.append(property)
        } catch {
          throw GeneratorError.illegalYamlScalarValue(error: "\(yamlValue) is not parsable")
        }
      }
    }
    return properties
  }
  
}
