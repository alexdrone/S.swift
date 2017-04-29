import Foundation

func search(basePath: String = ".", fileExtension: String) -> [String] {
  let args = [String](CommandLine.arguments)
  let task = Process()
  task.launchPath = "/usr/bin/find"
  task.arguments = ["\(args[1])", "\"*.\(fileExtension)\""]
  let pipe = Pipe()
  task.standardOutput = pipe
  task.standardError = nil
  task.launch()

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let output: String = String(data: data, encoding: String.Encoding.utf8)!
  let files = output.components(separatedBy: "\n").filter() {
    return $0.hasSuffix(".\(fileExtension)")
  }
  return files
}

func search(basePath: String = ".") -> [String] {
  return
      search(basePath: basePath, fileExtension: "yaml")
      + search(basePath: basePath, fileExtension: "yml")
}

func rm(file: String) {
  let task = Process()
  task.launchPath = "/bin/rm"
  task.arguments = [file]
  let pipe = Pipe()
  task.standardOutput = pipe;
  task.launch()
}

func touch(file: String) {
  let task = Process()
  task.launchPath = "/usr/bin/touch"
  task.arguments = [file]
  let pipe = Pipe()
  task.standardOutput = pipe;
  task.launch()
}

func destination(file: String) -> String {
  var c = file.components(separatedBy: "/")
  var fnc = (c.last!).components(separatedBy: ".")
  fnc.removeLast()
  fnc.append("generated")
  fnc.append("swift")
  let f = fnc.joined(separator: ".")
  c.removeLast()
  c.append(f)
  let p = c.joined(separator: "/")
  return p
}

func generate(file: String) {
  let url = NSURL(fileURLWithPath: file)
  if url.absoluteString!.contains(".swiftlint.yml") || url.absoluteString!.hasPrefix(".") {
    return
  }
  let generator = try! Generator(url: url as URL)
  let payload = generator.generate()
  let dest = destination(file: file)
  rm(file: dest)
  //touch(dest)
  sleep(1)
  try! payload.write(toFile: dest, atomically: true, encoding: String.Encoding.utf8)
  print("\(dest) generated.")
}

var args = [String](CommandLine.arguments)
if args.count == 1 {
  print("\n")
  print("usage: sgen PROJECT_PATH (--file FILENAME) --name STYLESHEET_NAME (--platform ios|osx) (--extensions internal|public) (--appExtension) (--objc) --import FRAMEWORKS")
  print("--file: If you're targetting one single file.")
  print("--name: The default is S.")
  print("--platform: use the **platform** argument to target the desired platform. The default one is **ios**")
  print("--extensions: Creates extensions for the views that have a style defined in the stylesheet. *public* and *internal* define what the extensions' visibility modifier should be.")
  print("--appExtensions: Generates a stylesheet with only apis allowed in the app extensions.")
  print("--objc: Generates **Swift** code that is interoperable with **Objective C**")
  print("\n")
  print("If you wish to **update** the generator, copy and paste this in your terminal:")
  print("curl \"https://raw.githubusercontent.com/alexdrone/S/master/sgen\" > sgen && mv sgen /usr/local/bin/sgen && chmod +x /usr/local/bin/sgen\n\n")
  exit(1)
}

// Configuration.
if args.contains("--objc") { Configuration.objcGeneration = true }
if args.contains("--appExtension") { Configuration.appExtensionApiOnly = true }
if args.contains("--extensions") { Configuration.extensionsEnabled = true }
if args.contains("public") { Configuration.publicExtensions = true }
if args.contains("--platform") && args.contains("osx") { Configuration.targetOsx = true }
if args.contains("--file") {
  if let idx = args.index(of: "--file") {
    Configuration.singleFile = args[idx+1]
  }
}
if args.contains("--name") {
  if let idx = args.index(of: "--name") {
    Configuration.stylesheetName = args[idx+1]
  }
}
if args.contains("--import") {
  if let idx = args.index(of: "--import") {
    Configuration.importFrameworks = args[idx+1]
  }
}

let path = args[1]
let files = search(basePath: path)
for file in files {
  if let target = Configuration.singleFile {
    if file.hasSuffix(target) {
      generate(file: file)
    }
  }
  generate(file: file)
}
