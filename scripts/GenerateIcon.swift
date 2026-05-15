#!/usr/bin/env swift
import AppKit

let size = 1024
let cx = CGFloat(size) / 2
let cy = CGFloat(size) / 2
let ringR: CGFloat = 295
let sw: CGFloat = 72

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Gradient background: lighter indigo top-left → deeper indigo bottom-right
let gradColors = [
    NSColor(red: 0.388, green: 0.400, blue: 0.945, alpha: 1).cgColor,
    NSColor(red: 0.263, green: 0.220, blue: 0.792, alpha: 1).cgColor
] as CFArray
let grad = CGGradient(colorsSpace: cs, colors: gradColors, locations: [0, 1])!
ctx.drawLinearGradient(
    grad,
    start: CGPoint(x: 0, y: CGFloat(size)),
    end: CGPoint(x: CGFloat(size), y: 0),
    options: []
)

// Background track ring (full circle, dimmed)
ctx.setStrokeColor(NSColor(white: 1, alpha: 0.2).cgColor)
ctx.setLineWidth(sw)
ctx.addEllipse(in: CGRect(x: cx - ringR, y: cy - ringR, width: ringR * 2, height: ringR * 2))
ctx.strokePath()

// Progress arc — 75%, starts at top (π/2), sweeps clockwise on screen
// In CGContext y-up: clockwise=true → clockwise in math plane → clockwise on screen
// From π/2 clockwise to π sweeps 270° (top → right → bottom → left)
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(sw)
ctx.setLineCap(.round)
ctx.addArc(
    center: CGPoint(x: cx, y: cy),
    radius: ringR,
    startAngle: .pi / 2,
    endAngle: .pi,
    clockwise: true
)
ctx.strokePath()

// Checkmark (y-up coords: high y = visually up on screen)
// Start: left middle → drop to lower-center bend → rise to upper-right
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(80)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 370, y: 510))
ctx.addLine(to: CGPoint(x: 468, y: 405))
ctx.addLine(to: CGPoint(x: 662, y: 618))
ctx.strokePath()

// Save
let img = ctx.makeImage()!
let bitmap = NSBitmapImageRep(cgImage: img)
let png = bitmap.representation(using: .png, properties: [:])!
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("Saved: \(out)")
