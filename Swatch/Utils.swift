//
//  Created by Alex Usbergo on 19/02/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//

import Foundation

/// Returns the arguments strings from a rule string
/// e.g. font("Comic Sans", 12) -> ["Comic Sans", "12"]
func argumentsFromString(key: String, string: String) -> [String]? {
    
    let input = string.stringByReplacingOccurrencesOfString(key.capitalizedString, withString: key);
    
    if !input.hasPrefix(key) {
        return nil
    }
    
    //remove the parenthesis
    var parsableString = input.stringByReplacingOccurrencesOfString("\(key)(", withString: "")
    parsableString = parsableString.stringByReplacingOccurrencesOfString(")", withString: "")
    return parsableString.componentsSeparatedByString(",")
}

/// Parse a number from a string
func parseNumber(string: String) -> Float {
    var input = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    input = (input as NSString).stringByReplacingOccurrencesOfString("\"", withString: "")
    
    input = input.stringByReplacingOccurrencesOfString("-", withString: "")
    input = input.stringByReplacingOccurrencesOfString("\"", withString: "")
    let scanner = NSScanner(string: input)
    let sign: Float = string.containsString("-") ? -1 : 1
    var numberBuffer: Float = 0
    if scanner.scanFloat(&numberBuffer) {
        return numberBuffer * sign;
    }
    return 0
}

/// Additional preprocessing for the string
func preprocessInput(string: String) -> String {
    var result = string.stringByReplacingOccurrencesOfString("#", withString: "color(");
    result = result.stringByReplacingOccurrencesOfString("$", withString: "redirect(");
    return result
}




