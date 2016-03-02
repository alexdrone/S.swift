//
//  Generator.swift
//  Swatch
//
//  Created by Alex Usbergo on 20/02/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//

import Foundation

public struct Configuration {
    public static var objcGeneration = false
    public static var extensionsEnabled = false
    public static var publicExtensions = false
    public static var targetOsx = false
}


public enum GeneratorError: ErrorType {
    case FileDoesNotExist(error: String)
    case MalformedYaml(error: String)
    case IllegalYamlScalarValue(error: String)

}

public protocol Generatable {
    
    ///Returns the swift code for this item
    func generate() -> String
}

public struct Generator: Generatable  {
    
    private var stylesheet: Stylesheet? = nil
    
    ///Initialise the Generator with some YAML payload
    public init(url: NSURL) throws {
        
        //loads the stylesheet
        var string = ""
        do { string = try String(contentsOfURL: url)
        } catch { throw GeneratorError.FileDoesNotExist(error: "File \(url) not found.") }
        
        string = preprocessInput(string)
        
        let yaml = Yaml.load(string)
        
        //all of the styles
        var styles = [Style]()

        switch yaml.value! {
        case .Dictionary(let main):
            for (key, values) in main {
                let properties = try self.createProperties(values.dictionary!)
                let style = Style(name: key.string!, properties: properties)
                styles.append(style)
            }
            
        default:
            throw GeneratorError.MalformedYaml(error: "The root is not a dictionary")
        }
        
        self.stylesheet = Stylesheet(name: "S", styles: styles)
    }
    
    ///Returns the swift code for this item
    public func generate() -> String {
        return self.stylesheet?.generate() ?? "Unable to generate stylesheet"
    }
    
    private func createProperties(dictionary: [Yaml: Yaml]) throws -> [Property] {
    
        var properties = [Property]()

        for (yamlKey, yamlValue) in dictionary {
            
            if let key = yamlKey.string {
                
                do {
                    
                    var rhsValue: RhsValue? = nil
                    
                    switch yamlValue {
                    case .Dictionary(let dictionary): rhsValue = try RhsValue.valueFrom(dictionary)
                    case .Bool(let boolean): rhsValue = RhsValue.valueFrom(boolean)
                    case .Double(let double): rhsValue = RhsValue.valueFrom(Float(double))
                    case .Int(let integer): rhsValue = RhsValue.valueFrom(Float(integer))
                    case .String(let string): rhsValue = try RhsValue.valueFrom(string)
                    default: throw GeneratorError.IllegalYamlScalarValue(error: "\(yamlValue) not supported as right-hand side value")
                    }
                    
                    let property = Property(key: key, rhs: rhsValue!)
                    properties.append(property)
                    
                } catch {
                    throw GeneratorError.IllegalYamlScalarValue(error: "\(yamlValue) is not parsable")
                }
                
            }
        }
        
        return properties
    }
    
}