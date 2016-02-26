//
//  Condition.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 20/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

internal enum ConditionError: ErrorType {
    case MalformedCondition(error: String)
    case MalformedRhsValue(error: String)
}

internal func ==<T:Parsable>(lhs: T, rhs: T) -> Bool {
    return lhs.rawString == rhs.rawString
}

func hash<T:Parsable>(item: T) -> Int {
    return item.rawString.hashValue;
}

internal protocol Parsable: Equatable {
    
    //the original string that originated this parsed item
    var rawString: String { get }
    
    init(rawString: String) throws
}


internal struct Condition: Hashable, Parsable {
    
    internal struct ExpressionToken {
        
        enum Default: String {
            case Default = "default"
            case External = "?"
        }
        
        enum Lhs: String {
            case Horizontal = "horizontal"
            case Vertical = "vertical"
            case Width = "width"
            case Height = "height"
            case Idiom = "idiom"
            case Unspecified = "unspecified"
        }
        
        enum Operator: String {
            case Equal = "="
            case NotEqual = "≠"
            case LessThan = "<"
            case LessThanOrEqual = "≤"
            case GreaterThan = ">"
            case GreaterThanOrEqual = "≥"
            case Unspecified = "unspecified"
            
            
            static func all() -> [Operator] {
                return [Equal, NotEqual, LessThan, LessThanOrEqual, GreaterThan, GreaterThanOrEqual]
            }
            
            static func allRaw() -> [String] {
                return [Equal.rawValue, NotEqual.rawValue, LessThan.rawValue, LessThanOrEqual.rawValue, GreaterThan.rawValue, GreaterThanOrEqual.rawValue]
            }
            
            static func characterSet() -> NSCharacterSet {
                return NSCharacterSet(charactersInString: self.allRaw().joinWithSeparator(""))
            }
            
            static func operatorContainedInString(string: String) -> Operator {
                for opr in self.all() {
                    if string.rangeOfString(opr.rawValue) != nil {
                        return opr
                    }
                }
                return Unspecified
            }
            
            func equal<T:Equatable>(lhs: T, rhs: T) -> Bool {
                switch self {
                case .Equal: return lhs == rhs
                case .NotEqual: return lhs != rhs
                default: return false
                }
            }
            
            func compare<T:Comparable>(lhs: T, rhs: T) -> Bool {
                switch self {
                case .Equal: return lhs == rhs
                case .NotEqual: return lhs != rhs
                case .LessThan: return lhs < rhs
                case .LessThanOrEqual: return lhs <= rhs
                case .GreaterThan: return lhs > rhs
                case .GreaterThanOrEqual: return lhs >= rhs
                default: return false
                }
            }
        }
        
        enum Rhs: String {
            case Regular = "regular"
            case Compact = "compact"
            case Pad = "pad"
            case Phone = "phone"
            case Constant = "_"
            case Unspecified = "unspecified"
        }
    }

    internal struct Expression: Hashable, Parsable {
        
        ///@see Parsable
        internal let rawString: String
        
        ///Wether this expression is always true or not
        private let tautology: Bool
        
        ///The actual parsed expression
        private let expression: (Condition.ExpressionToken.Lhs, Condition.ExpressionToken.Operator, Condition.ExpressionToken.Rhs, Float)
        
        
        //Hashable compliancy
        internal var hashValue: Int {
            get {
                return hash(self)
            }
        }
        
        internal init(rawString: String) throws {
            
            self.rawString = normalizeExpressionString(rawString)
            
            //check for default expression
            if self.rawString.rangeOfString(Condition.ExpressionToken.Default.Default.rawValue) != nil {
                
                self.expression = (.Unspecified, .Unspecified, .Unspecified, 0)
                self.tautology = true
                
            //expression
            } else {
                
                self.tautology = false
                var terms = self.rawString.componentsSeparatedByCharactersInSet(Condition.ExpressionToken.Operator.characterSet())
                let opr = Condition.ExpressionToken.Operator.operatorContainedInString(self.rawString)
                
                if terms.count != 2 || opr == Condition.ExpressionToken.Operator.Unspecified {
                    throw ConditionError.MalformedCondition(error: "No valid operator found in the string")
                }
                
                terms = terms.map({
                    return $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                })
                
                //initialise the
                let constant: Float
                let hasConstant: Bool
                
                if let c = Float(terms[1]) {
                    constant = c
                    hasConstant = true
                    
                } else {
                    constant = Float.NaN
                    hasConstant = false
                }
                
                guard   let lhs = Condition.ExpressionToken.Lhs(rawValue: terms[0]),
                        let rhs = hasConstant ? Condition.ExpressionToken.Rhs.Constant : Condition.ExpressionToken.Rhs(rawValue: terms[1]) else {
                        throw ConditionError.MalformedCondition(error: "The terms of the condition are not valid")
                }
                
                self.expression = (lhs, opr, rhs, constant)
            }
        }
        
    }
    
    ///@see Parsable
    internal let rawString: String
    var expressions: [Expression] = [Expression]()
    
    //Hashable compliancy
    internal var hashValue: Int {
        get {
            return hash(self)
        }
    }
    
    internal init(rawString: String) throws {
        
        self.rawString = normalizeExpressionString(rawString)
        
        let components = self.rawString.componentsSeparatedByString("and")
        for exprString in components {
            try expressions.append(Expression(rawString: exprString))
        }
    }
    
    internal func isDefault() -> Bool {
        return self.rawString.containsString("default")
    }
    
}

private func normalizeExpressionString(string: String, forceLowerCase: Bool = true) -> String {
    var ps = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    ps = (ps as NSString).stringByReplacingOccurrencesOfString("\"", withString: "")

    if forceLowerCase {
        ps = ps.lowercaseString
    }
    ps = ps.stringByReplacingOccurrencesOfString("\"", withString: "")
    ps = ps.stringByReplacingOccurrencesOfString("'", withString: "")
    ps = ps.stringByReplacingOccurrencesOfString("!=", withString: Condition.ExpressionToken.Operator.NotEqual.rawValue)
    ps = ps.stringByReplacingOccurrencesOfString("<=", withString: Condition.ExpressionToken.Operator.LessThanOrEqual.rawValue)
    ps = ps.stringByReplacingOccurrencesOfString(">=", withString: Condition.ExpressionToken.Operator.GreaterThanOrEqual.rawValue)
    ps = ps.stringByReplacingOccurrencesOfString("==", withString: Condition.ExpressionToken.Operator.Equal.rawValue)
    ps = ps.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    
    return ps
}

extension Condition: Generatable {

    ///Generates the code for this right hand side value
    internal func generate() -> String {

        var expressions = [String]()
        for expression in self.expressions {

            var string = ""
            switch expression.expression.0 {
            case .Height: string += "UIScreen.mainScreen().bounds.size.height "
            case .Width: string += "UIScreen.mainScreen().bounds.size.width "
            case .Horizontal: string += "traitCollection.horizontalSizeClass "
            case .Vertical: string += "traitCollection.verticalSizeClass "
            case .Idiom: string += "UIDevice.currentDevice().userInterfaceIdiom "
            case .Unspecified: string += "true "
            }

            switch expression.expression.1 {
            case .Equal: string += "== "
            case .NotEqual: string += "!= "
            case .GreaterThan: string += "> "
            case .GreaterThanOrEqual: string += ">= "
            case .LessThan: string += "< "
            case .LessThanOrEqual: string += "<= "
            case .Unspecified: string += ""
            }

            switch expression.expression.2 {
            case .Constant: string += "\(expression.expression.3) "
            case .Compact: string += "UIUserInterfaceSizeClass.Compact "
            case .Regular: string += "UIUserInterfaceSizeClass.Regular "
            case .Pad: string += "UIUserInterfaceIdiom.Pad "
            case .Phone: string += "UIUserInterfaceIdiom.Phone "
            case .Unspecified: string += ""
            }

            expressions.append(string)
        }

        return expressions.joinWithSeparator(" && ")
    }


}