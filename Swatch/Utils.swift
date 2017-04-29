import Foundation

/// Returns the arguments strings from a rule string
/// e.g. font("Comic Sans", 12) -> ["Comic Sans", "12"]
func argumentsFromString(_ key: String, string: String) -> [String]? {
  let input = string.replacingOccurrences(of: key.capitalized, with: key);
  if !input.hasPrefix(key) {
    return nil
  }

  // Remove the parenthesis.
  var parsableString = input.replacingOccurrences(of: "\(key)(", with: "")
  parsableString = parsableString.replacingOccurrences(of: ")", with: "")
  return parsableString.components(separatedBy: ",")
}

/// Parse a number from a string.
func parseNumber(_ string: String) -> Float {
  var input = string.trimmingCharacters(in: CharacterSet.whitespaces)
  input = (input as NSString).replacingOccurrences(of: "\"", with: "")

  input = input.replacingOccurrences(of: "-", with: "")
  input = input.replacingOccurrences(of: "\"", with: "")
  let scanner = Scanner(string: input)
  let sign: Float = string.contains("-") ? -1 : 1
  var numberBuffer: Float = 0
  if scanner.scanFloat(&numberBuffer) {
    return numberBuffer * sign;
  }
  return 0
}

/// Additional preprocessing for the string.
func preprocessInput(_ string: String) -> String {
  var result = string.replacingOccurrences(of: "#", with: "color(");
  result = result.replacingOccurrences(of: "$", with: "redirect(");
  return result
}
