#!/usr/bin/env python3
"""Generate app icon for NTFS Mac using CoreGraphics (macOS native)."""
import subprocess
import os
import math

ICON_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "NTFSMac", "Assets.xcassets", "AppIcon.appiconset")

SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def generate_svg(size):
    """Generate an SVG icon with a hard drive and NTFS text."""
    # Scale factor relative to 1024
    s = size / 1024.0

    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg width="{size}" height="{size}" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <!-- Background rounded rectangle -->
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#4A90D9;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#2563EB;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="drive" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#F8FAFC;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#E2E8F0;stop-opacity:1" />
    </linearGradient>
  </defs>

  <!-- Background -->
  <rect x="0" y="0" width="1024" height="1024" rx="220" ry="220" fill="url(#bg)"/>

  <!-- Hard drive body -->
  <rect x="180" y="320" width="664" height="420" rx="40" ry="40" fill="url(#drive)" stroke="#CBD5E1" stroke-width="8"/>

  <!-- Drive slot line -->
  <rect x="220" y="580" width="584" height="4" rx="2" fill="#94A3B8"/>

  <!-- Drive indicator light -->
  <circle cx="700" cy="650" r="20" fill="#22C55E"/>

  <!-- Drive ventilation dots -->
  <circle cx="280" cy="650" r="12" fill="#94A3B8"/>
  <circle cx="330" cy="650" r="12" fill="#94A3B8"/>
  <circle cx="380" cy="650" r="12" fill="#94A3B8"/>

  <!-- NTFS text -->
  <text x="512" y="510" font-family="SF Pro Display, Helvetica Neue, Arial" font-size="160" font-weight="bold" fill="#1E40AF" text-anchor="middle" dominant-baseline="middle">NTFS</text>

  <!-- Arrow (read/write indicator) -->
  <polygon points="512,180 580,260 545,260 545,310 479,310 479,260 444,260" fill="#FFFFFF" opacity="0.95"/>
</svg>'''
    return svg


def main():
    os.makedirs(ICON_DIR, exist_ok=True)

    for filename, size in SIZES:
        svg_content = generate_svg(size)
        svg_path = os.path.join(ICON_DIR, filename.replace('.png', '.svg'))
        png_path = os.path.join(ICON_DIR, filename)

        # Write SVG
        with open(svg_path, 'w') as f:
            f.write(svg_content)

        # Convert SVG to PNG using sips (macOS built-in) via rsvg or qlmanage
        # Use `sips` with a temporary file approach or `qlmanage`
        # Best approach: use `sips` to convert from SVG isn't direct,
        # so we'll use Python + AppKit
        try:
            convert_svg_to_png(svg_path, png_path, size)
            os.remove(svg_path)
            print(f"  ✓ {filename} ({size}x{size})")
        except Exception as e:
            print(f"  ✗ {filename}: {e}")
            # Fallback: keep SVG, try alternate method
            try:
                convert_with_qlmanage(svg_path, png_path, size)
                os.remove(svg_path)
                print(f"  ✓ {filename} ({size}x{size}) [qlmanage]")
            except Exception as e2:
                print(f"  ✗ {filename}: fallback also failed: {e2}")

    print("\nDone! Icons generated in:", ICON_DIR)


def convert_svg_to_png(svg_path, png_path, size):
    """Convert SVG to PNG using AppKit/CoreGraphics."""
    script = f'''
import AppKit
import Foundation

svg_path = "{svg_path}"
png_path = "{png_path}"
size = {size}

# Load SVG as NSImage
image = AppKit.NSImage.alloc().initWithContentsOfFile_(svg_path)
if image is None:
    raise Exception("Failed to load SVG")

# Create a new image with exact size
new_image = AppKit.NSImage.alloc().initWithSize_(AppKit.NSMakeSize(size, size))
new_image.lockFocus()
image.drawInRect_fromRect_operation_fraction_(
    AppKit.NSMakeRect(0, 0, size, size),
    AppKit.NSZeroRect,
    AppKit.NSCompositingOperationSourceOver,
    1.0
)
new_image.unlockFocus()

# Get PNG data
tiff_data = new_image.TIFFRepresentation()
bitmap = AppKit.NSBitmapImageRep.imageRepWithData_(tiff_data)
png_data = bitmap.representationUsingType_properties_(AppKit.NSBitmapImageFileTypePNG, {{}})
png_data.writeToFile_atomically_(png_path, True)
'''
    result = subprocess.run(
        ['python3', '-c', script],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise Exception(result.stderr.strip())


def convert_with_qlmanage(svg_path, png_path, size):
    """Fallback: use qlmanage to generate thumbnail."""
    result = subprocess.run(
        ['qlmanage', '-t', '-s', str(size), '-o', os.path.dirname(png_path), svg_path],
        capture_output=True, text=True
    )
    # qlmanage outputs as filename.svg.png
    ql_output = svg_path + ".png"
    if os.path.exists(ql_output):
        os.rename(ql_output, png_path)
    elif result.returncode != 0:
        raise Exception(result.stderr.strip())


if __name__ == '__main__':
    print("Generating NTFS Mac app icons...")
    main()
