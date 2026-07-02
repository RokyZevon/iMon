#!/usr/bin/env swift
import AppKit
import Foundation

let invocationDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let scriptURL = URL(fileURLWithPath: #filePath, relativeTo: invocationDirectory).standardizedFileURL
let root = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let icns = resources.appendingPathComponent("AppIcon.icns")
let svg = resources.appendingPathComponent("AppIcon.svg")
let assetsCar = resources.appendingPathComponent("Assets.car")

let sizes: [(name: String, points: Int, scale: String, pixels: Int)] = [
    ("icon_16x16.png", 16, "1x", 16),
    ("icon_16x16@2x.png", 16, "2x", 32),
    ("icon_32x32.png", 32, "1x", 32),
    ("icon_32x32@2x.png", 32, "2x", 64),
    ("icon_128x128.png", 128, "1x", 128),
    ("icon_128x128@2x.png", 128, "2x", 256),
    ("icon_256x256.png", 256, "1x", 256),
    ("icon_256x256@2x.png", 256, "2x", 512),
    ("icon_512x512.png", 512, "1x", 512),
    ("icon_512x512@2x.png", 512, "2x", 1024)
]

struct IconColor {
    let hex: UInt32

    var color: NSColor {
        NSColor(
            deviceRed: CGFloat((hex >> 16) & 0xff) / 255.0,
            green: CGFloat((hex >> 8) & 0xff) / 255.0,
            blue: CGFloat(hex & 0xff) / 255.0,
            alpha: 1
        )
    }

    var svgHex: String {
        String(format: "#%06X", hex)
    }
}

struct Palette {
    let backgroundTop: IconColor
    let backgroundBottom: IconColor
    let railTop: IconColor
    let railBottom: IconColor
    let pressure: IconColor
    let pressureAccent: IconColor
    let innerLine: IconColor
    let border: IconColor
}

let lightPalette = Palette(
    backgroundTop: IconColor(hex: 0xFFF8EC),
    backgroundBottom: IconColor(hex: 0xEFE8DA),
    railTop: IconColor(hex: 0x1F9E98),
    railBottom: IconColor(hex: 0x205B78),
    pressure: IconColor(hex: 0xE9A23B),
    pressureAccent: IconColor(hex: 0xC8613D),
    innerLine: IconColor(hex: 0xF8DCA6),
    border: IconColor(hex: 0xD7C9B4)
)

let darkPalette = Palette(
    backgroundTop: IconColor(hex: 0x24201B),
    backgroundBottom: IconColor(hex: 0x0F0E0C),
    railTop: IconColor(hex: 0x55D6C2),
    railBottom: IconColor(hex: 0x8ECAE6),
    pressure: IconColor(hex: 0xF2A23A),
    pressureAccent: IconColor(hex: 0xFF6F4B),
    innerLine: IconColor(hex: 0xFFE1A6),
    border: IconColor(hex: 0x3C3328)
)

enum Appearance {
    case light
    case dark

    var suffix: String {
        switch self {
        case .light: return ""
        case .dark: return "_dark"
        }
    }

    var palette: Palette {
        switch self {
        case .light: return lightPalette
        case .dark: return darkPalette
        }
    }
}

func installGeneratedFile(from source: URL, to destination: URL) throws {
    let staged = destination
        .deletingLastPathComponent()
        .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
    defer {
        try? FileManager.default.removeItem(at: staged)
    }

    try FileManager.default.copyItem(at: source, to: staged)
    if FileManager.default.fileExists(atPath: destination.path) {
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
    } else {
        do {
            try FileManager.default.moveItem(at: staged, to: destination)
        } catch {
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
            } else {
                throw error
            }
        }
    }
}

func writeSVG() throws {
    let light = lightPalette
    let dark = darkPalette
    let text = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
      <style>
        .bgTop { stop-color: \(light.backgroundTop.svgHex); }
        .bgBottom { stop-color: \(light.backgroundBottom.svgHex); }
        .railTop { fill: \(light.railTop.svgHex); }
        .railBottom { fill: \(light.railBottom.svgHex); }
        .pressure { fill: \(light.pressure.svgHex); }
        .pressureAccent { fill: \(light.pressureAccent.svgHex); }
        .innerLine { fill: \(light.innerLine.svgHex); opacity: 0.75; }
        .border { stroke: \(light.border.svgHex); }
        @media (prefers-color-scheme: dark) {
          .bgTop { stop-color: \(dark.backgroundTop.svgHex); }
          .bgBottom { stop-color: \(dark.backgroundBottom.svgHex); }
          .railTop { fill: \(dark.railTop.svgHex); }
          .railBottom { fill: \(dark.railBottom.svgHex); }
          .pressure { fill: \(dark.pressure.svgHex); }
          .pressureAccent { fill: \(dark.pressureAccent.svgHex); }
          .innerLine { fill: \(dark.innerLine.svgHex); opacity: 0.7; }
          .border { stroke: \(dark.border.svgHex); }
        }
      </style>
      <defs>
        <linearGradient id="bg" x1="512" y1="72" x2="512" y2="952" gradientUnits="userSpaceOnUse">
          <stop offset="0" class="bgTop"/>
          <stop offset="1" class="bgBottom"/>
        </linearGradient>
      </defs>
      <rect x="72" y="72" width="880" height="880" rx="218" fill="url(#bg)" class="border" stroke-width="24"/>
      <g transform="translate(0 1024) scale(1 -1)">
        <rect x="224" y="588" width="456" height="108" rx="54" class="railTop"/>
        <rect x="344" y="328" width="456" height="108" rx="54" class="railBottom"/>
        <rect x="462" y="392" width="120" height="240" rx="60" class="pressure"/>
        <rect x="500" y="442" width="44" height="140" rx="22" class="innerLine"/>
        <rect x="594" y="468" width="108" height="36" rx="18" class="pressureAccent"/>
      </g>
    </svg>
    """
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    try text.write(to: svg, atomically: true, encoding: .utf8)
}

func drawIcon(pixels: Int, appearance: Appearance, to url: URL) throws {
    let size = CGFloat(pixels)
    let scale = size / 1024.0
    let palette = appearance.palette

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "iMon.IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate bitmap"])
    }

    bitmap.size = NSSize(width: size, height: size)

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "iMon.IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    func r(_ value: CGFloat) -> CGFloat { value * scale }
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: r(x), y: r(y), width: r(w), height: r(h))
    }
    func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect(x, y, w, h), xRadius: r(radius), yRadius: r(radius))
    }

    let background = roundedRect(72, 72, 880, 880, 218)
    let gradient = NSGradient(starting: palette.backgroundTop.color, ending: palette.backgroundBottom.color)
    gradient?.draw(in: background, angle: 90)

    palette.border.color.setStroke()
    background.lineWidth = max(1, r(24))
    background.stroke()

    palette.railTop.color.setFill()
    roundedRect(224, 588, 456, 108, 54).fill()

    palette.railBottom.color.setFill()
    roundedRect(344, 328, 456, 108, 54).fill()

    palette.pressure.color.setFill()
    roundedRect(462, 392, 120, 240, 60).fill()

    palette.innerLine.color.withAlphaComponent(appearance == .light ? 0.75 : 0.7).setFill()
    roundedRect(500, 442, 44, 140, 22).fill()

    palette.pressureAccent.color.setFill()
    roundedRect(594, 468, 108, 36, 18).fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "iMon.IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to render PNG"])
    }
    try png.write(to: url)
}

func assetFilename(for item: (name: String, points: Int, scale: String, pixels: Int), appearance: Appearance) -> String {
    let base = item.name.replacingOccurrences(of: ".png", with: "")
    return "\(base)\(appearance.suffix).png"
}

func writeAssetCatalogContents(xcassets: URL, appiconset: URL) throws {
    try """
    {
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """.write(to: xcassets.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    var imageEntries: [String] = []
    for item in sizes {
        imageEntries.append("""
            {
              "filename" : "\(assetFilename(for: item, appearance: .light))",
              "idiom" : "mac",
              "scale" : "\(item.scale)",
              "size" : "\(item.points)x\(item.points)"
            }
        """)

        imageEntries.append("""
            {
              "appearances" : [
                {
                  "appearance" : "luminosity",
                  "value" : "dark"
                }
              ],
              "filename" : "\(assetFilename(for: item, appearance: .dark))",
              "idiom" : "mac",
              "scale" : "\(item.scale)",
              "size" : "\(item.points)x\(item.points)"
            }
        """)
    }

    let contents = """
    {
      "images" : [
    \(imageEntries.joined(separator: ",\n"))
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try contents.write(to: appiconset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func shellQuoted(_ value: String) -> String {
    if value.range(of: #"[^A-Za-z0-9_./:=+-]"#, options: .regularExpression) == nil {
        return value
    }
    return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let outputRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("imon-command-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: outputRoot)
    }

    let stdoutURL = outputRoot.appendingPathComponent("stdout.txt")
    let stderrURL = outputRoot.appendingPathComponent("stderr.txt")
    FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
    FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
    let stdout = try FileHandle(forWritingTo: stdoutURL)
    let stderr = try FileHandle(forWritingTo: stderrURL)
    defer {
        try? stdout.close()
        try? stderr.close()
    }
    process.standardOutput = stdout
    process.standardError = stderr
    let command = ([executable] + arguments).map(shellQuoted).joined(separator: " ")
    do {
        try process.run()
    } catch {
        throw NSError(
            domain: "iMon.IconGeneration",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to run command: \(command)\n\(error.localizedDescription)"]
        )
    }
    process.waitUntilExit()
    try? stdout.close()
    try? stderr.close()
    let stdoutText = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
    let stderrText = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
    guard process.terminationStatus == 0 else {
        throw NSError(
            domain: "iMon.IconGeneration",
            code: Int(process.terminationStatus),
            userInfo: [
                NSLocalizedDescriptionKey: """
                Command failed with exit status \(process.terminationStatus): \(command)
                stdout:
                \(stdoutText.isEmpty ? "<empty>" : stdoutText)
                stderr:
                \(stderrText.isEmpty ? "<empty>" : stderrText)
                """
            ]
        )
    }
}

func compileFinalAssets() throws {
    let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("imon-appicon-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let xcassets = tempRoot.appendingPathComponent("Assets.xcassets", isDirectory: true)
    let appiconset = xcassets.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
    let compileOutput = tempRoot.appendingPathComponent("Compiled", isDirectory: true)
    let partialPlist = tempRoot.appendingPathComponent("AppIcon.partial.plist")

    try FileManager.default.createDirectory(at: appiconset, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: compileOutput, withIntermediateDirectories: true)

    for item in sizes {
        for appearance in [Appearance.light, .dark] {
            let url = appiconset.appendingPathComponent(assetFilename(for: item, appearance: appearance))
            try drawIcon(pixels: item.pixels, appearance: appearance, to: url)
        }
    }
    try writeAssetCatalogContents(xcassets: xcassets, appiconset: appiconset)

    try run("/usr/bin/xcrun", [
        "actool",
        "--compile", compileOutput.path,
        "--platform", "macosx",
        "--minimum-deployment-target", "13.0",
        "--app-icon", "AppIcon",
        "--standalone-icon-behavior", "all",
        "--output-partial-info-plist", partialPlist.path,
        xcassets.path
    ])

    let compiledAssets = compileOutput.appendingPathComponent("Assets.car")
    let compiledIcon = compileOutput.appendingPathComponent("AppIcon.icns")
    guard FileManager.default.fileExists(atPath: compiledAssets.path) else {
        throw NSError(domain: "iMon.IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "actool did not produce Assets.car"])
    }
    guard FileManager.default.fileExists(atPath: compiledIcon.path) else {
        throw NSError(domain: "iMon.IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "actool did not produce AppIcon.icns"])
    }

    try installGeneratedFile(from: compiledAssets, to: assetsCar)
    try installGeneratedFile(from: compiledIcon, to: icns)
}

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try writeSVG()
try compileFinalAssets()

print("Generated \(icns.path)")
print("Generated \(assetsCar.path)")
