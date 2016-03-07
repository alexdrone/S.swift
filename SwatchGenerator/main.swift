//
//  main.swift
//  SwatchGenerator
//
//  Created by Alex Usbergo on 19/02/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//

import Foundation

func search(basePath: String = ".", fileExtension: String) -> [String] {
    let args = [String](Process.arguments)
    
    let task = NSTask()
    task.launchPath = "/usr/bin/find"
    task.arguments = ["\(args[1])", "\"*.\(fileExtension)\""]
    let pipe = NSPipe()
    task.standardOutput = pipe
    task.standardError = nil
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output: String = String(data: data, encoding: NSUTF8StringEncoding)!
    let files = output.componentsSeparatedByString("\n").filter() { return $0.hasSuffix(".\(fileExtension)") }
    
    return files
}

func search(basePath: String = ".") -> [String] {
    return search(basePath, fileExtension: "yaml") + search(basePath, fileExtension: "yml")
}

func rm(file: String) {
    let task = NSTask()
    task.launchPath = "/bin/rm"
    task.arguments = [file]
    let pipe = NSPipe()
    task.standardOutput = pipe;
    task.launch()
}

func touch(file: String) {
    let task = NSTask()
    task.launchPath = "/usr/bin/touch"
    task.arguments = [file]
    let pipe = NSPipe()
    task.standardOutput = pipe;
    task.launch()
}

func destination(file: String) -> String {
    var c = file.componentsSeparatedByString("/")
    var fnc = (c.last!).componentsSeparatedByString(".")
    fnc.removeLast()
    fnc.append("generated")
    fnc.append("swift")
    let f = fnc.joinWithSeparator(".")
    c.removeLast()
    c.append(f)
    let p = c.joinWithSeparator("/")
    return p
}

func generate(file: String) {

    let url = NSURL(fileURLWithPath: file)
    
    if url.absoluteString.containsString(".swiftlint.yml") {
        return
    }
    
    let generator = try! Generator(url: url)
    let payload = generator.generate()
    let dest = destination(file)
    
    rm(dest)
    //touch(dest)
    sleep(1)
    try! payload.writeToFile(dest, atomically: true, encoding: NSUTF8StringEncoding)
    
    print("\(dest) generated.")
}

var args = [String](Process.arguments)

if args.count == 1 {
    print("\n")
    print("usage: sgen PROJECT_PATH (--platform ios|osx) (--extensions internal|public) (--objc)")
    print("--platform: use the **platform** argument to target the desired platform. The default one is **ios**")
    print("--extensions: Creates extensions for the views that have a style defined in the stylesheet. *public* and *internal* define what the extensions' visibility modifier should be.")
    print("--objc: generates **Swift** code that is interoperable with **Objective C**")
    print("\n")
    print("If you wish to **update** the generator, copy and paste this in your terminal:")
    print("curl \"https://raw.githubusercontent.com/alexdrone/S/master/sgen\" > sgen && mv sgen /usr/local/bin/sgen && chmod +x /usr/local/bin/sgen\n\n")
    exit(1)
}

//configuration
if args.contains("--objc") { Configuration.objcGeneration = true }
if args.contains("--extensions") { Configuration.extensionsEnabled = true }
if args.contains("public") { Configuration.publicExtensions = true }
if args.contains("--platform") && args.contains("osx") { Configuration.targetOsx = true }

let path = args[1]
let files = search(path)

for file in files {
    generate(file)
}


