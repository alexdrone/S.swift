//
//  Created by Alex Usbergo on 19/02/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//
// Forked from behrang/YamlSwift
//

import Foundation

infix operator |> { associativity left }
func |> <T, U> (x: T, f: T -> U) -> U {
  return f(x)
}

func count<T:CollectionType>(collection: T) -> T.Index.Distance {
  return collection.count
}

func count(string: String) -> String.Index.Distance {
  return string.characters.count
}

struct Context {
  let tokens: [TokenMatch]
  let aliases: [String: Yaml]

  init (_ tokens: [TokenMatch], _ aliases: [String: Yaml] = [:]) {
    self.tokens = tokens
    self.aliases = aliases
  }
}

typealias ContextValue = (context: Context, value: Yaml)
func createContextValue (context: Context) -> Yaml -> ContextValue {
  return { value in (context, value) }
}
func getContext (cv: ContextValue) -> Context {
  return cv.context
}
func getValue (cv: ContextValue) -> Yaml {
  return cv.value
}

func parseDoc (tokens: [TokenMatch]) -> Result<Yaml> {
  let c = lift(Context(tokens))
  let cv = c >>=- parseHeader >>=- parse
  let v = cv >>- getValue
  return cv
    >>- getContext
    >>- ignoreDocEnd
    >>=- expect(TokenType.End, message: "expected end")
    >>| v
}

func parseDocs (tokens: [TokenMatch]) -> Result<[Yaml]> {
  return parseDocs([])(Context(tokens))
}

func parseDocs (acc: [Yaml]) -> Context -> Result<[Yaml]> {
  return { context in
    if peekType(context) == .End {
      return lift(acc)
    }
    let cv = lift(context)
      >>=- parseHeader
      >>=- parse
    let v = cv
      >>- getValue
    let c = cv
      >>- getContext
      >>- ignoreDocEnd
    let a = appendToArray(acc) <^> v
    return parseDocs <^> a <*> c |> join
  }
}

func peekType (context: Context) -> TokenType {
  return context.tokens[0].type
}

func peekMatch (context: Context) -> String {
  return context.tokens[0].match
}

func advance (context: Context) -> Context {
  var tokens = context.tokens
  tokens.removeAtIndex(0)
  return Context(tokens, context.aliases)
}

func ignoreSpace (context: Context) -> Context {
  if ![.Comment, .Space, .NewLine].contains(peekType(context)) {
    return context
  }
  return ignoreSpace(advance(context))
}

func ignoreDocEnd (context: Context) -> Context {
  if ![.Comment, .Space, .NewLine, .DocEnd].contains(peekType(context)) {
    return context
  }
  return ignoreDocEnd(advance(context))
}

func expect (type: TokenType, message: String) -> Context -> Result<Context> {
  return { context in
    let check = peekType(context) == type
    return `guard`(error(message)(context), check: check)
      >>| lift(advance(context))
  }
}

func expectVersion (context: Context) -> Result<Context> {
  let version = peekMatch(context)
  let check = ["1.1", "1.2"].contains(version)
  return `guard`(error("invalid yaml version")(context), check: check)
    >>| lift(advance(context))
}

func error (message: String) -> Context -> String {
  return { context in
    let text = recreateText("", context: context) |> escapeErrorContext
    return "\(message), \(text)"
  }
}

func recreateText (string: String, context: Context) -> String {
  if string.characters.count >= 50 || peekType(context) == .End {
    return string
  }
  return recreateText(string + peekMatch(context), context: advance(context))
}

func parseHeader (context: Context) -> Result<Context> {
  return parseHeader(true)(Context(context.tokens, [:]))
}

func parseHeader (yamlAllowed: Bool) -> Context -> Result<Context> {
  return { context in
    switch peekType(context) {

    case .Comment, .Space, .NewLine:
      return lift(context)
        >>- advance
        >>=- parseHeader(yamlAllowed)

    case .YamlDirective:
      let err = "duplicate yaml directive"
      return `guard`(error(err)(context), check: yamlAllowed)
        >>| lift(context)
        >>- advance
        >>=- expect(TokenType.Space, message: "expected space")
        >>=- expectVersion
        >>=- parseHeader(false)

    case .DocStart:
      return lift(advance(context))

    default:
      return `guard`(error("expected ---")(context), check: yamlAllowed)
        >>| lift(context)
    }
  }
}

func parse (context: Context) -> Result<ContextValue> {
  switch peekType(context) {

  case .Comment, .Space, .NewLine:
    return parse(ignoreSpace(context))

  case .Null:
    return lift((advance(context), nil))

  case .True:
    return lift((advance(context), true))

  case .False:
    return lift((advance(context), false))

  case .Int:
    let m = peekMatch(context)
    // will throw runtime error if overflows
    let v = Yaml.Int(parseInt(m, radix: 10))
    return lift((advance(context), v))

  case .IntOct:
    let m = peekMatch(context) |> replace(regex("0o"), template: "")
    // will throw runtime error if overflows
    let v = Yaml.Int(parseInt(m, radix: 8))
    return lift((advance(context), v))

  case .IntHex:
    let m = peekMatch(context) |> replace(regex("0x"), template: "")
    // will throw runtime error if overflows
    let v = Yaml.Int(parseInt(m, radix: 16))
    return lift((advance(context), v))

  case .IntSex:
    let m = peekMatch(context)
    let v = Yaml.Int(parseInt(m, radix: 60))
    return lift((advance(context), v))

  case .InfinityP:
    return lift((advance(context), .Double(Double.infinity)))

  case .InfinityN:
    return lift((advance(context), .Double(-Double.infinity)))

  case .NaN:
    return lift((advance(context), .Double(Double.NaN)))

  case .Double:
    let m = peekMatch(context) as NSString
    return lift((advance(context), .Double(m.doubleValue)))

  case .Dash:
    return parseBlockSeq(context)

  case .OpenSB:
    return parseFlowSeq(context)

  case .OpenCB:
    return parseFlowMap(context)

  case .QuestionMark:
    return parseBlockMap(context)

  case .StringDQ, .StringSQ, .String:
    return parseBlockMapOrString(context)

  case .Literal:
    return parseLiteral(context)

  case .Folded:
    let cv = parseLiteral(context)
    let c = cv >>- getContext
    let v = cv
      >>- getValue
      >>- { value in Yaml.String(foldBlock(value.string ?? "")) }
    return createContextValue <^> c <*> v

  case .Indent:
    let cv = parse(advance(context))
    let v = cv >>- getValue
    let c = cv
      >>- getContext
      >>- ignoreSpace
      >>=- expect(TokenType.Dedent, message: "expected dedent")
    return createContextValue <^> c <*> v

  case .Anchor:
    let m = peekMatch(context)
    let name = m.substringFromIndex(m.startIndex.successor())
    let cv = parse(advance(context))
    let v = cv >>- getValue
    let c = addAlias(name) <^> v <*> (cv >>- getContext)
    return createContextValue <^> c <*> v

  case .Alias:
    let m = peekMatch(context)
    let name = m.substringFromIndex(m.startIndex.successor())
    let value = context.aliases[name]
    let err = "unknown alias \(name)"
    return `guard`(error(err)(context), check: value != nil)
      >>| lift((advance(context), value ?? nil))

  case .End, .Dedent:
    return lift((context, nil))

  default:
    return fail(error("unexpected type \(peekType(context))")(context))

  }
}

func addAlias (name: String) -> Yaml -> Context -> Context {
  return { value in
    return { context in
      var aliases = context.aliases
      aliases[name] = value
      return Context(context.tokens, aliases)
    }
  }
}

func appendToArray (array: [Yaml]) -> Yaml -> [Yaml] {
  return { value in
    return array + [value]
  }
}

func putToMap (map: [Yaml: Yaml]) -> Yaml -> Yaml -> [Yaml: Yaml] {
  return { key in
    return { value in
      var map = map
      map[key] = value
      return map
    }
  }
}

func checkKeyUniqueness (acc: [Yaml: Yaml]) -> (context: Context, key: Yaml)
  -> Result<ContextValue> {
    return { (context, key) in
      let err = "duplicate key \(key)"
      return `guard`(error(err)(context), check: !acc.keys.contains(key))
        >>| lift((context, key))
    }
}

func parseFlowSeq (context: Context) -> Result<ContextValue> {
  return lift(context)
    >>=- expect(TokenType.OpenSB, message: "expected [")
    >>=- parseFlowSeq([])
}

func parseFlowSeq (acc: [Yaml]) -> Context -> Result<ContextValue> {
  return { context in
    if peekType(context) == .CloseSB {
      return lift((advance(context), .Array(acc)))
    }
    let cv = lift(context)
      >>- ignoreSpace
      >>=- (acc.count == 0 ? lift : expect(TokenType.Comma, message: "expected comma"))
      >>- ignoreSpace
      >>=- parse
    let v = cv >>- getValue
    let c = cv
      >>- getContext
      >>- ignoreSpace
    let a = appendToArray(acc) <^> v
    return parseFlowSeq <^> a <*> c |> join
  }
}

func parseFlowMap (context: Context) -> Result<ContextValue> {
  return lift(context)
    >>=- expect(TokenType.OpenCB, message: "expected {")
    >>=- parseFlowMap([:])
}

func parseFlowMap (acc: [Yaml: Yaml]) -> Context -> Result<ContextValue> {
  return { context in
    if peekType(context) == .CloseCB {
      return lift((advance(context), .Dictionary(acc)))
    }
    let ck = lift(context)
      >>- ignoreSpace
      >>=- (acc.count == 0 ? lift : expect(TokenType.Comma, message: "expected comma"))
      >>- ignoreSpace
      >>=- parseString
      >>=- checkKeyUniqueness(acc)
    let k = ck >>- getValue
    let cv = ck
      >>- getContext
      >>=- expect(TokenType.Colon, message: "expected colon")
      >>=- parse
    let v = cv >>- getValue
    let c = cv
      >>- getContext
      >>- ignoreSpace
    let a = putToMap(acc) <^> k <*> v
    return parseFlowMap <^> a <*> c |> join
  }
}

func parseBlockSeq (context: Context) -> Result<ContextValue> {
  return parseBlockSeq([])(context)
}

func parseBlockSeq (acc: [Yaml]) -> Context -> Result<ContextValue> {
  return { context in
    if peekType(context) != .Dash {
      return lift((context, .Array(acc)))
    }
    let cv = lift(context)
      >>- advance
      >>=- expect(TokenType.Indent, message: "expected indent after dash")
      >>- ignoreSpace
      >>=- parse
    let v = cv >>- getValue
    let c = cv
      >>- getContext
      >>- ignoreSpace
      >>=- expect(TokenType.Dedent, message: "expected dedent after dash indent")
      >>- ignoreSpace
    let a = appendToArray(acc) <^> v
    return parseBlockSeq <^> a <*> c |> join
  }
}

func parseBlockMap (context: Context) -> Result<ContextValue> {
  return parseBlockMap([:])(context)
}

func parseBlockMap (acc: [Yaml: Yaml]) -> Context -> Result<ContextValue> {
  return { context in
    switch peekType(context) {

    case .QuestionMark:
      return parseQuestionMarkKeyValue(acc)(context)

    case .String, .StringDQ, .StringSQ:
      return parseStringKeyValue(acc)(context)

    default:
      return lift((context, .Dictionary(acc)))
    }
  }
}

func parseQuestionMarkKeyValue (acc: [Yaml: Yaml]) -> Context -> Result<ContextValue> {
  return { context in
    let ck = lift(context)
      >>=- expect(TokenType.QuestionMark, message: "expected ?")
      >>=- parse
      >>=- checkKeyUniqueness(acc)
    let k = ck >>- getValue
    let cv = ck
      >>- getContext
      >>- ignoreSpace
      >>=- parseColonValueOrNil
    let v = cv >>- getValue
    let c = cv
      >>- getContext
      >>- ignoreSpace
    let a = putToMap(acc) <^> k <*> v
    return parseBlockMap <^> a <*> c |> join
  }
}

func parseColonValueOrNil (context: Context) -> Result<ContextValue> {
  if peekType(context) != .Colon {
    return lift((context, nil))
  }
  return parseColonValue(context)
}

func parseColonValue (context: Context) -> Result<ContextValue> {
  return lift(context)
    >>=- expect(TokenType.Colon, message: "expected colon")
    >>- ignoreSpace
    >>=- parse
}

func parseStringKeyValue (acc: [Yaml: Yaml]) -> Context -> Result<ContextValue> {
  return { context in
    let ck = lift(context)
      >>=- parseString
      >>=- checkKeyUniqueness(acc)
    let k = ck >>- getValue
    let cv = ck
      >>- getContext
      >>- ignoreSpace
      >>=- parseColonValue
    let v = cv >>- getValue
    let c = cv
      >>- getContext
      >>- ignoreSpace
    let a = putToMap(acc) <^> k <*> v
    return parseBlockMap <^> a <*> c |> join
  }
}

func parseString (context: Context) -> Result<ContextValue> {
  switch peekType(context) {

  case .String:
    let m = normalizeBreaks(peekMatch(context))
    let folded = m |> replace(regex("^[ \\t\\n]+|[ \\t\\n]+$"), template: "") |> foldFlow
    return lift((advance(context), .String(folded)))

  case .StringDQ:
    let m = unwrapQuotedString(normalizeBreaks(peekMatch(context)))
    return lift((advance(context), .String(unescapeDoubleQuotes(foldFlow(m)))))

  case .StringSQ:
    let m = unwrapQuotedString(normalizeBreaks(peekMatch(context)))
    return lift((advance(context), .String(unescapeSingleQuotes(foldFlow(m)))))

  default:
    return fail(error("expected string")(context))
  }
}

func parseBlockMapOrString (context: Context) -> Result<ContextValue> {
  let match = peekMatch(context)
  // should spaces before colon be ignored?
  return context.tokens[1].type != .Colon || matches(match, regex: regex("\n"))
    ? parseString(context)
    : parseBlockMap(context)
}

func foldBlock (block: String) -> String {
  let (body, trail) = block |> splitTrail(regex("\\n*$"))
  return (body
    |> replace(regex("^([^ \\t\\n].*)\\n(?=[^ \\t\\n])", options: "m"), template: "$1 ")
    |> replace(
      regex("^([^ \\t\\n].*)\\n(\\n+)(?![ \\t])", options: "m"), template: "$1$2")
    ) + trail
}

func foldFlow (flow: String) -> String {
  let (lead, rest) = flow |> splitLead(regex("^[ \\t]+"))
  let (body, trail) = rest |> splitTrail(regex("[ \\t]+$"))
  let folded = body
    |> replace(regex("^[ \\t]+|[ \\t]+$|\\\\\\n", options: "m"), template: "")
    |> replace(regex("(^|.)\\n(?=.|$)"), template: "$1 ")
    |> replace(regex("(.)\\n(\\n+)"), template: "$1$2")
  return lead + folded + trail
}

func parseLiteral (context: Context) -> Result<ContextValue> {
  let literal = peekMatch(context)
  let blockContext = advance(context)
  let chomps = ["-": -1, "+": 1]
  let chomp = chomps[literal |> replace(regex("[^-+]"), template: "")] ?? 0
  let indent = parseInt(literal |> replace(regex("[^1-9]"), template: ""), radix: 10)
  let headerPattern = regex("^(\\||>)([1-9][-+]|[-+]?[1-9]?)( |$)")
  let error0 = "invalid chomp or indent header"
  let c = `guard`(error(error0)(context),
                  check: matches(literal, regex: headerPattern))
    >>| lift(blockContext)
    >>=- expect(TokenType.String, message: "expected scalar block")
  let block = peekMatch(blockContext)
    |> normalizeBreaks
  let (lead, _) = block
    |> splitLead(regex("^( *\\n)* {1,}(?! |\\n|$)"))
  let foundIndent = lead
    |> replace(regex("^( *\\n)*"), template: "")
    |> count
  let effectiveIndent = indent > 0 ? indent : foundIndent
  let invalidPattern =
    regex("^( {0,\(effectiveIndent)}\\n)* {\(effectiveIndent + 1),}\\n")
  let check1 = matches(block, regex: invalidPattern)
  let check2 = indent > 0 && foundIndent < indent
  let trimmed = block
    |> replace(regex("^ {0,\(effectiveIndent)}"), template: "")
    |> replace(regex("\\n {0,\(effectiveIndent)}"), template: "\n")
    |> (chomp == -1
      ? replace(regex("(\\n *)*$"), template: "")
      : chomp == 0
      ? replace(regex("(?=[^ ])(\\n *)*$"), template: "\n")
      : { s in s }
  )
  let error1 = "leading all-space line must not have too many spaces"
  let error2 = "less indented block scalar than the indicated level"
  return c
    >>| `guard`(error(error1)(blockContext), check: !check1)
    >>| `guard`(error(error2)(blockContext), check: !check2)
    >>| c
    >>- { context in (context, .String(trimmed))}
}

func parseInt (string: String, radix: Int) -> Int {
  let (sign, str) = splitLead(regex("^[-+]"))(string)
  let multiplier = (sign == "-" ? -1 : 1)
  let ints = radix == 60
    ? toSexInts(str)
    : toInts(str)
  return multiplier * ints.reduce(0, combine: { acc, i in acc * radix + i })
}

func toSexInts (string: String) -> [Int] {
  return string.componentsSeparatedByString(":").map {
    c in Int(c) ?? 0
  }
}

func toInts (string: String) -> [Int] {
  return string.unicodeScalars.map {
    c in
    switch c {
    case "0"..."9": return Int(c.value) - Int(UnicodeScalar("0").value)
    case "a"..."z": return Int(c.value) - Int(UnicodeScalar("a").value) + 10
    case "A"..."Z": return Int(c.value) - Int(UnicodeScalar("A").value) + 10
    default: fatalError("invalid digit \(c)")
    }
  }
}

func normalizeBreaks (s: String) -> String {
  return replace(regex("\\r\\n|\\r"), template: "\n")(s)
}

func unwrapQuotedString (s: String) -> String {
  return s[s.startIndex.successor()..<s.endIndex.predecessor()]
}

func unescapeSingleQuotes (s: String) -> String {
  return replace(regex("''"), template: "'")(s)
}

func unescapeDoubleQuotes (input: String) -> String {
  return input
    |> replace(regex("\\\\([0abtnvfre \"\\/N_LP])"))
    { $ in escapeCharacters[$[1]] ?? "" }
    |> replace(regex("\\\\x([0-9A-Fa-f]{2})"))
    { $ in String(UnicodeScalar(parseInt($[1], radix: 16))) }
    |> replace(regex("\\\\u([0-9A-Fa-f]{4})"))
    { $ in String(UnicodeScalar(parseInt($[1], radix: 16))) }
    |> replace(regex("\\\\U([0-9A-Fa-f]{8})"))
    { $ in String(UnicodeScalar(parseInt($[1], radix: 16))) }
}

let escapeCharacters = [
  "0": "\0",
  "a": "\u{7}",
  "b": "\u{8}",
  "t": "\t",
  "n": "\n",
  "v": "\u{B}",
  "f": "\u{C}",
  "r": "\r",
  "e": "\u{1B}",
  " ": " ",
  "\"": "\"",
  "\\": "\\",
  "/": "/",
  "N": "\u{85}",
  "_": "\u{A0}",
  "L": "\u{2028}",
  "P": "\u{2029}"
]

import Foundation

func matchRange (string: String, regex: NSRegularExpression) -> NSRange {
  let sr = NSMakeRange(0, string.utf16.count)
  return regex.rangeOfFirstMatchInString(string, options: [], range: sr)
}

func matches (string: String, regex: NSRegularExpression) -> Bool {
  return matchRange(string, regex: regex).location != NSNotFound
}

func regex (pattern: String, options: String = "") -> NSRegularExpression! {
  if matches(options, regex: invalidOptionsPattern) {
    return nil
  }

  let opts = options.characters.reduce(NSRegularExpressionOptions()) { (acc, opt) -> NSRegularExpressionOptions in
    return NSRegularExpressionOptions(rawValue:acc.rawValue | (regexOptions[opt] ?? NSRegularExpressionOptions()).rawValue)
  }
  do {
    return try NSRegularExpression(pattern: pattern, options: opts)
  } catch _ {
    return nil
  }
}

let invalidOptionsPattern =
  try! NSRegularExpression(pattern: "[^ixsm]", options: [])

let regexOptions: [Character: NSRegularExpressionOptions] = [
  "i": .CaseInsensitive,
  "x": .AllowCommentsAndWhitespace,
  "s": .DotMatchesLineSeparators,
  "m": .AnchorsMatchLines
]

func replace (regex: NSRegularExpression, template: String) -> String
  -> String {
    return { string in
      let s = NSMutableString(string: string)
      let range = NSMakeRange(0, string.utf16.count)
      regex.replaceMatchesInString(s, options: [], range: range,
                                   withTemplate: template)
      return s as String
    }
}

func replace (regex: NSRegularExpression, block: [String] -> String)
  -> String -> String {
    return { string in
      let s = NSMutableString(string: string)
      let range = NSMakeRange(0, string.utf16.count)
      var offset = 0
      regex.enumerateMatchesInString(string, options: [], range: range) {
        result, _, _ in
        if let result = result {
          var captures = [String](count: result.numberOfRanges, repeatedValue: "")
          for i in 0..<result.numberOfRanges {
            if let r = result.rangeAtIndex(i).toRange() {
              captures[i] = (string as NSString).substringWithRange(NSRange(r))
            }
          }
          let replacement = block(captures)
          let offR = NSMakeRange(result.range.location + offset, result.range.length)
          offset += replacement.characters.count - result.range.length
          s.replaceCharactersInRange(offR, withString: replacement)
        }
      }
      return s as String
    }
}

func splitLead (regex: NSRegularExpression) -> String
  -> (String, String) {
    return { string in
      let r = matchRange(string, regex: regex)
      if r.location == NSNotFound {
        return ("", string)
      } else {
        let s = string as NSString
        let i = r.location + r.length
        return (s.substringToIndex(i), s.substringFromIndex(i))
      }
    }
}

func splitTrail (regex: NSRegularExpression) -> String
  -> (String, String) {
    return { string in
      let r = matchRange(string, regex: regex)
      if r.location == NSNotFound {
        return (string, "")
      } else {
        let s = string as NSString
        let i = r.location
        return (s.substringToIndex(i), s.substringFromIndex(i))
      }
    }
}

func substringWithRange (range: NSRange) -> String -> String {
  return { string in
    return (string as NSString).substringWithRange(range)
  }
}

func substringFromIndex (index: Int) -> String -> String {
  return { string in
    return (string as NSString).substringFromIndex(index)
  }
}

func substringToIndex (index: Int) -> String -> String {
  return { string in
    return (string as NSString).substringToIndex(index)
  }
}

public enum Result<T> {
  case Error(String)
  case Value(Box<T>)

  public var error: String? {
    switch self {
    case .Error(let e): return e
    case .Value: return nil
    }
  }

  public var value: T? {
    switch self {
    case .Error: return nil
    case .Value(let v): return v.value
    }
  }

  public func map <U> (f: T -> U) -> Result<U> {
    switch self {
    case .Error(let e): return .Error(e)
    case .Value(let v): return .Value(Box(f(v.value)))
    }
  }

  public func flatMap <U> (f: T -> Result<U>) -> Result<U> {
    switch self {
    case .Error(let e): return .Error(e)
    case .Value(let v): return f(v.value)
    }
  }
}

infix operator <*> { associativity left }
func <*> <T, U> (f: Result<T -> U>, x: Result<T>) -> Result<U> {
  switch (x, f) {
  case (.Error(let e), _): return .Error(e)
  case (.Value, .Error(let e)): return .Error(e)
  case (.Value(let x), .Value(let f)): return .Value(Box(f.value(x.value)))
  }
}

infix operator <^> { associativity left }
func <^> <T, U> (f: T -> U, x: Result<T>) -> Result<U> {
  return x.map(f)
}

infix operator >>- { associativity left }
func >>- <T, U> (x: Result<T>, f: T -> U) -> Result<U> {
  return x.map(f)
}

infix operator >>=- { associativity left }
func >>=- <T, U> (x: Result<T>, f: T -> Result<U>) -> Result<U> {
  return x.flatMap(f)
}

infix operator >>| { associativity left }
func >>| <T, U> (x: Result<T>, y: Result<U>) -> Result<U> {
  return x.flatMap { _ in y }
}

func lift <V> (v: V) -> Result<V> {
  return .Value(Box(v))
}

func fail <T> (e: String) -> Result<T> {
  return .Error(e)
}

func join <T> (x: Result<Result<T>>) -> Result<T> {
  return x >>=- { i in i }
}

func `guard` (@autoclosure error: () -> String, check: Bool) -> Result<()> {
  return check ? lift(()) : .Error(error())
}

// Required for boxing for now.
public class Box<T> {
  let _value: () -> T

  init(_ value: T) {
    _value = { value }
  }

  var value: T {
    return _value()
  }
}


import Foundation

enum TokenType: Swift.String, CustomStringConvertible {
  case YamlDirective = "%YAML"
  case DocStart = "doc-start"
  case DocEnd = "doc-end"
  case Comment = "comment"
  case Space = "space"
  case NewLine = "newline"
  case Indent = "indent"
  case Dedent = "dedent"
  case Null = "null"
  case True = "true"
  case False = "false"
  case InfinityP = "+infinity"
  case InfinityN = "-infinity"
  case NaN = "nan"
  case Double = "double"
  case Int = "int"
  case IntOct = "int-oct"
  case IntHex = "int-hex"
  case IntSex = "int-sex"
  case Anchor = "&"
  case Alias = "*"
  case Comma = ","
  case OpenSB = "["
  case CloseSB = "]"
  case Dash = "-"
  case OpenCB = "{"
  case CloseCB = "}"
  case Key = "key"
  case KeyDQ = "key-dq"
  case KeySQ = "key-sq"
  case QuestionMark = "?"
  case ColonFO = ":-flow-out"
  case ColonFI = ":-flow-in"
  case Colon = ":"
  case Literal = "|"
  case Folded = ">"
  case Reserved = "reserved"
  case StringDQ = "string-dq"
  case StringSQ = "string-sq"
  case StringFI = "string-flow-in"
  case StringFO = "string-flow-out"
  case String = "string"
  case End = "end"

  var description: Swift.String {
    return self.rawValue
  }
}

typealias TokenPattern = (type: TokenType, pattern: NSRegularExpression)
typealias TokenMatch = (type: TokenType, match: String)

let bBreak = "(?:\\r\\n|\\r|\\n)"

// printable non-space chars,
// except `:`(3a), `#`(23), `,`(2c), `[`(5b), `]`(5d), `{`(7b), `}`(7d)
let safeIn = "\\x21\\x22\\x24-\\x2b\\x2d-\\x39\\x3b-\\x5a\\x5c\\x5e-\\x7a" +
  "\\x7c\\x7e\\x85\\xa0-\\ud7ff\\ue000-\\ufefe\\uff00\\ufffd" +
"\\U00010000-\\U0010ffff"
// with flow indicators: `,`, `[`, `]`, `{`, `}`
let safeOut = "\\x2c\\x5b\\x5d\\x7b\\x7d" + safeIn
let plainOutPattern =
  "([\(safeOut)]#|:(?![ \\t]|\(bBreak))|[\(safeOut)]|[ \\t])+"
let plainInPattern =
  "([\(safeIn)]#|:(?![ \\t]|\(bBreak))|[\(safeIn)]|[ \\t]|\(bBreak))+"
let dashPattern = regex("^-([ \\t]+(?!#|\(bBreak))|(?=[ \\t\\n]))")
let finish = "(?= *(,|\\]|\\}|( #.*)?(\(bBreak)|$)))"
let tokenPatterns: [TokenPattern] = [
  (.YamlDirective, regex("^%YAML(?= )")),
  (.DocStart, regex("^---")),
  (.DocEnd, regex("^\\.\\.\\.")),
  (.Comment, regex("^#.*|^\(bBreak) *(#.*)?(?=\(bBreak)|$)")),
  (.Space, regex("^ +")),
  (.NewLine, regex("^\(bBreak) *")),
  (.Dash, dashPattern),
  (.Null, regex("^(null|Null|NULL|~)\(finish)")),
  (.True, regex("^(true|True|TRUE)\(finish)")),
  (.False, regex("^(false|False|FALSE)\(finish)")),
  (.InfinityP, regex("^\\+?\\.(inf|Inf|INF)\(finish)")),
  (.InfinityN, regex("^-\\.(inf|Inf|INF)\(finish)")),
  (.NaN, regex("^\\.(nan|NaN|NAN)\(finish)")),
  (.Int, regex("^[-+]?[0-9]+\(finish)")),
  (.IntOct, regex("^0o[0-7]+\(finish)")),
  (.IntHex, regex("^0x[0-9a-fA-F]+\(finish)")),
  (.IntSex, regex("^[0-9]{2}(:[0-9]{2})+\(finish)")),
  (.Double, regex("^[-+]?(\\.[0-9]+|[0-9]+(\\.[0-9]*)?)([eE][-+]?[0-9]+)?\(finish)")),
  (.Anchor, regex("^&\\w+")),
  (.Alias, regex("^\\*\\w+")),
  (.Comma, regex("^,")),
  (.OpenSB, regex("^\\[")),
  (.CloseSB, regex("^\\]")),
  (.OpenCB, regex("^\\{")),
  (.CloseCB, regex("^\\}")),
  (.QuestionMark, regex("^\\?( +|(?=\(bBreak)))")),
  (.ColonFO, regex("^:(?!:)")),
  (.ColonFI, regex("^:(?!:)")),
  (.Literal, regex("^\\|.*")),
  (.Folded, regex("^>.*")),
  (.Reserved, regex("^[@`]")),
  (.StringDQ, regex("^\"([^\\\\\"]|\\\\(.|\(bBreak)))*\"")),
  (.StringSQ, regex("^'([^']|'')*'")),
  (.StringFO, regex("^\(plainOutPattern)(?=:([ \\t]|\(bBreak))|\(bBreak)|$)")),
  (.StringFI, regex("^\(plainInPattern)")),
]

func escapeErrorContext (text: String) -> String {
  let endIndex = text.startIndex.advancedBy(50, limit: text.endIndex)
  let escaped = text.substringToIndex(endIndex)
    |> replace(regex("\\r"), template: "\\\\r")
    |> replace(regex("\\n"), template: "\\\\n")
    |> replace(regex("\""), template: "\\\\\"")
  return "near \"\(escaped)\""
}

func tokenize (text: String) -> Result<[TokenMatch]> {
  var text = text
  var matchList: [TokenMatch] = []
  var indents = [0]
  var insideFlow = 0
  next:
    while text.endIndex > text.startIndex {
      for tokenPattern in tokenPatterns {
        let range = matchRange(text, regex: tokenPattern.pattern)
        if range.location != NSNotFound {
          let rangeEnd = range.location + range.length
          switch tokenPattern.type {

          case .NewLine:
            let match = text |> substringWithRange(range)
            let lastIndent = indents.last ?? 0
            let rest = match.substringFromIndex(match.startIndex.successor())
            let spaces = rest.characters.count
            let nestedBlockSequence =
              matches(text |> substringFromIndex(rangeEnd), regex: dashPattern)
            if spaces == lastIndent {
              matchList.append(TokenMatch(.NewLine, match))
            } else if spaces > lastIndent {
              if insideFlow == 0 {
                if matchList.last != nil &&
                  matchList[matchList.endIndex - 1].type == .Indent {
                  indents[indents.endIndex - 1] = spaces
                  matchList[matchList.endIndex - 1] = TokenMatch(.Indent, match)
                } else {
                  indents.append(spaces)
                  matchList.append(TokenMatch(.Indent, match))
                }
              }
            } else if nestedBlockSequence && spaces == lastIndent - 1 {
              matchList.append(TokenMatch(.NewLine, match))
            } else {
              while nestedBlockSequence && spaces < (indents.last ?? 0) - 1
                || !nestedBlockSequence && spaces < indents.last {
                  indents.removeLast()
                  matchList.append(TokenMatch(.Dedent, ""))
              }
              matchList.append(TokenMatch(.NewLine, match))
            }

          case .Dash, .QuestionMark:
            let match = text |> substringWithRange(range)
            let index = match.startIndex.successor()
            let indent = match.characters.count
            indents.append((indents.last ?? 0) + indent)
            matchList.append(
              TokenMatch(tokenPattern.type, match.substringToIndex(index)))
            matchList.append(TokenMatch(.Indent, match.substringFromIndex(index)))

          case .ColonFO:
            if insideFlow > 0 {
              continue
            }
            fallthrough

          case .ColonFI:
            let match = text |> substringWithRange(range)
            matchList.append(TokenMatch(.Colon, match))
            if insideFlow == 0 {
              indents.append((indents.last ?? 0) + 1)
              matchList.append(TokenMatch(.Indent, ""))
            }

          case .OpenSB, .OpenCB:
            insideFlow += 1
            matchList.append(TokenMatch(tokenPattern.type, text |> substringWithRange(range)))

          case .CloseSB, .CloseCB:
            insideFlow -= 1
            matchList.append(TokenMatch(tokenPattern.type, text |> substringWithRange(range)))

          case .Literal, .Folded:
            matchList.append(TokenMatch(tokenPattern.type, text |> substringWithRange(range)))
            text = text |> substringFromIndex(rangeEnd)
            let lastIndent = indents.last ?? 0
            let minIndent = 1 + lastIndent
            let blockPattern = regex(("^(\(bBreak) *)*(\(bBreak)" +
              "( {\(minIndent),})[^ ].*(\(bBreak)( *|\\3.*))*)(?=\(bBreak)|$)"))
            let (lead, rest) = text |> splitLead(blockPattern)
            text = rest
            let block = (lead
              |> replace(regex("^\(bBreak)"), template: "")
              |> replace(regex("^ {0,\(lastIndent)}"), template: "")
              |> replace(regex("\(bBreak) {0,\(lastIndent)}"), template: "\n")
              ) + (matches(text, regex: regex("^\(bBreak)")) && lead.endIndex > lead.startIndex
                ? "\n" : "")
            matchList.append(TokenMatch(.String, block))
            continue next

          case .StringFO:
            if insideFlow > 0 {
              continue
            }
            let indent = (indents.last ?? 0)
            let blockPattern = regex(("^\(bBreak)( *| {\(indent),}" +
              "\(plainOutPattern))(?=\(bBreak)|$)"))
            var block = text
              |> substringWithRange(range)
              |> replace(regex("^[ \\t]+|[ \\t]+$"), template: "")
            text = text |> substringFromIndex(rangeEnd)
            while true {
              let range = matchRange(text, regex: blockPattern)
              if range.location == NSNotFound {
                break
              }
              let s = text |> substringWithRange(range)
              block += "\n" +
                replace(regex("^\(bBreak)[ \\t]*|[ \\t]+$"), template: "")(s)
              text = text |> substringFromIndex(range.location + range.length)
            }
            matchList.append(TokenMatch(.String, block))
            continue next

          case .StringFI:
            let match = text
              |> substringWithRange(range)
              |> replace(regex("^[ \\t]|[ \\t]$"), template: "")
            matchList.append(TokenMatch(.String, match))

          case .Reserved:
            return fail(escapeErrorContext(text))

          default:
            matchList.append(TokenMatch(tokenPattern.type, text |> substringWithRange(range)))
          }
          text = text |> substringFromIndex(rangeEnd)
          continue next
        }
      }
      return fail(escapeErrorContext(text))
  }
  while indents.count > 1 {
    indents.removeLast()
    matchList.append((.Dedent, ""))
  }
  matchList.append((.End, ""))
  return lift(matchList)
}

public enum Yaml {
  case Null
  case Bool(Swift.Bool)
  case Int(Swift.Int)
  case Double(Swift.Double)
  case String(Swift.String)
  case Array([Yaml])
  case Dictionary([Yaml: Yaml])
}

extension Yaml: NilLiteralConvertible {
  public init(nilLiteral: ()) {
    self = .Null
  }
}

extension Yaml: BooleanLiteralConvertible {
  public init(booleanLiteral: BooleanLiteralType) {
    self = .Bool(booleanLiteral)
  }
}

extension Yaml: IntegerLiteralConvertible {
  public init(integerLiteral: IntegerLiteralType) {
    self = .Int(integerLiteral)
  }
}

extension Yaml: FloatLiteralConvertible {
  public init(floatLiteral: FloatLiteralType) {
    self = .Double(floatLiteral)
  }
}

extension Yaml: StringLiteralConvertible {
  public init(stringLiteral: StringLiteralType) {
    self = .String(stringLiteral)
  }

  public init(extendedGraphemeClusterLiteral: StringLiteralType) {
    self = .String(extendedGraphemeClusterLiteral)
  }

  public init(unicodeScalarLiteral: StringLiteralType) {
    self = .String(unicodeScalarLiteral)
  }
}

extension Yaml: ArrayLiteralConvertible {
  public init(arrayLiteral elements: Yaml...) {
    var array = [Yaml]()
    array.reserveCapacity(elements.count)
    for element in elements {
      array.append(element)
    }
    self = .Array(array)
  }
}

extension Yaml: DictionaryLiteralConvertible {
  public init(dictionaryLiteral elements: (Yaml, Yaml)...) {
    var dictionary = [Yaml: Yaml]()
    for (k, v) in elements {
      dictionary[k] = v
    }
    self = .Dictionary(dictionary)
  }
}

extension Yaml: CustomStringConvertible {
  public var description: Swift.String {
    switch self {
    case .Null:
      return "Null"
    case .Bool(let b):
      return "Bool(\(b))"
    case .Int(let i):
      return "Int(\(i))"
    case .Double(let f):
      return "Double(\(f))"
    case .String(let s):
      return "String(\(s))"
    case .Array(let s):
      return "Array(\(s))"
    case .Dictionary(let m):
      return "Dictionary(\(m))"
    }
  }
}

extension Yaml: Hashable {
  public var hashValue: Swift.Int {
    return description.hashValue
  }
}

extension Yaml {
  public static func load (text: Swift.String) -> Result<Yaml> {
    return tokenize(text) >>=- parseDoc
  }

  public static func loadMultiple (text: Swift.String) -> Result<[Yaml]> {
    return tokenize(text) >>=- parseDocs
  }

  public static func debug (text: Swift.String) -> Result<Yaml> {
    let result = tokenize(text)
      >>- { tokens in print("\n====== Tokens:\n\(tokens)"); return tokens }
      >>=- parseDoc
      >>- { value -> Yaml in print("------ Doc:\n\(value)"); return value }
    if let error = result.error {
      print("~~~~~~\n\(error)")
    }
    return result
  }

  public static func debugMultiple (text: Swift.String) -> Result<[Yaml]> {
    let result = tokenize(text)
      >>- { tokens in print("\n====== Tokens:\n\(tokens)"); return tokens }
      >>=- parseDocs
      >>- { values -> [Yaml] in values.forEach {
        v in print("------ Doc:\n\(v)")
        }; return values }
    if let error = result.error {
      print("~~~~~~\n\(error)")
    }
    return result
  }
}

extension Yaml {
  public subscript(index: Swift.Int) -> Yaml {
    get {
      assert(index >= 0)
      switch self {
      case .Array(let array):
        if index >= array.startIndex && index < array.endIndex {
          return array[index]
        } else {
          return .Null
        }
      default:
        return .Null
      }
    }
    set {
      assert(index >= 0)
      switch self {
      case .Array(let array):
        let emptyCount = max(0, index + 1 - array.count)
        let empty = [Yaml](count: emptyCount, repeatedValue: .Null)
        var new = array
        new.appendContentsOf(empty)
        new[index] = newValue
        self = .Array(new)
      default:
        var array = [Yaml](count: index + 1, repeatedValue: .Null)
        array[index] = newValue
        self = .Array(array)
      }
    }
  }

  public subscript(key: Yaml) -> Yaml {
    get {
      switch self {
      case .Dictionary(let dictionary):
        return dictionary[key] ?? .Null
      default:
        return .Null
      }
    }
    set {
      switch self {
      case .Dictionary(let dictionary):
        var new = dictionary
        new[key] = newValue
        self = .Dictionary(new)
      default:
        var dictionary = [Yaml: Yaml]()
        dictionary[key] = newValue
        self = .Dictionary(dictionary)
      }
    }
  }
}

extension Yaml {
  public var bool: Swift.Bool? {
    switch self {
    case .Bool(let b):
      return b
    default:
      return nil
    }
  }

  public var int: Swift.Int? {
    switch self {
    case .Int(let i):
      return i
    case .Double(let f):
      if Swift.Double(Swift.Int(f)) == f {
        return Swift.Int(f)
      } else {
        return nil
      }
    default:
      return nil
    }
  }

  public var double: Swift.Double? {
    switch self {
    case .Double(let f):
      return f
    case .Int(let i):
      return Swift.Double(i)
    default:
      return nil
    }
  }

  public var string: Swift.String? {
    switch self {
    case .String(let s):
      return s
    default:
      return nil
    }
  }

  public var array: [Yaml]? {
    switch self {
    case .Array(let array):
      return array
    default:
      return nil
    }
  }

  public var dictionary: [Yaml: Yaml]? {
    switch self {
    case .Dictionary(let dictionary):
      return dictionary
    default:
      return nil
    }
  }

  public var count: Swift.Int? {
    switch self {
    case .Array(let array):
      return array.count
    case .Dictionary(let dictionary):
      return dictionary.count
    default:
      return nil
    }
  }
}

public func == (lhs: Yaml, rhs: Yaml) -> Bool {
  switch lhs {

  case .Null:
    switch rhs {
    case .Null:
      return true
    default:
      return false
    }

  case .Bool(let lv):
    switch rhs {
    case .Bool(let rv):
      return lv == rv
    default:
      return false
    }

  case .Int(let lv):
    switch rhs {
    case .Int(let rv):
      return lv == rv
    case .Double(let rv):
      return Double(lv) == rv
    default:
      return false
    }

  case .Double(let lv):
    switch rhs {
    case .Double(let rv):
      return lv == rv
    case .Int(let rv):
      return lv == Double(rv)
    default:
      return false
    }

  case .String(let lv):
    switch rhs {
    case .String(let rv):
      return lv == rv
    default:
      return false
    }

  case .Array(let lv):
    switch rhs {
    case .Array(let rv) where lv.count == rv.count:
      for i in 0..<lv.count {
        if lv[i] != rv[i] {
          return false
        }
      }
      return true
    default:
      return false
    }

  case .Dictionary(let lv):
    switch rhs {
    case .Dictionary(let rv) where lv.count == rv.count:
      for (k, v) in lv {
        if rv[k] == nil || rv[k] != v {
          return false
        }
      }
      return true
    default:
      return false
    }
  }
}

public func != (lhs: Yaml, rhs: Yaml) -> Bool {
  return !(lhs == rhs)
}

// unary `-` operator
public prefix func - (value: Yaml) -> Yaml {
  switch value {
  case .Int(let v):
    return .Int(-v)
  case .Double(let v):
    return .Double(-v)
  default:
    fatalError("`-` operator may only be used on .Int or .Double Yaml values")
  }
}
