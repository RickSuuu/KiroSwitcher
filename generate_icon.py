#!/usr/bin/env python3
"""Generate KiroSwitcher app icon (.icns) — blue lightning bolt on dark background."""
import subprocess, os, struct, zlib, math

def create_png(width, height, pixels):
    def chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    raw = b''
    for y in range(height):
        raw += b'\x00'
        for x in range(width):
            idx = (y * width + x) * 4
            raw += bytes(pixels[idx:idx+4])
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(raw, 9)
    return sig + chunk(b'IHDR', ihdr) + chunk(b'IDAT', idat) + chunk(b'IEND', b'')

def draw_icon(size):
    pixels = [0] * (size * size * 4)
    s = size / 1024.0
    corner_radius = int(size * 0.22)
    
    # Colors
    bg = (22, 22, 28)           # Dark background
    blue = (77, 143, 245)       # Kiro blue
    light_blue = (130, 180, 255) # Highlight
    
    def in_rounded_rect(x, y, w, h, r):
        if x < r and y < r:
            return (x - r)**2 + (y - r)**2 <= r**2
        if x >= w - r and y < r:
            return (x - (w - r - 1))**2 + (y - r)**2 <= r**2
        if x < r and y >= h - r:
            return (x - r)**2 + (y - (h - r - 1))**2 <= r**2
        if x >= w - r and y >= h - r:
            return (x - (w - r - 1))**2 + (y - (h - r - 1))**2 <= r**2
        return True
    
    def set_pixel(x, y, r, g, b, a=255):
        x, y = int(x), int(y)
        if 0 <= x < size and 0 <= y < size:
            idx = (y * size + x) * 4
            pixels[idx] = r; pixels[idx+1] = g; pixels[idx+2] = b; pixels[idx+3] = a
    
    def fill_polygon(points, r, g, b):
        """Fill a polygon using scanline."""
        if not points: return
        min_y = max(0, int(min(p[1] for p in points)))
        max_y = min(size - 1, int(max(p[1] for p in points)))
        for y in range(min_y, max_y + 1):
            intersections = []
            n = len(points)
            for i in range(n):
                x1, y1 = points[i]
                x2, y2 = points[(i + 1) % n]
                if y1 == y2: continue
                if min(y1, y2) <= y < max(y1, y2):
                    x_int = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
                    intersections.append(x_int)
            intersections.sort()
            for j in range(0, len(intersections) - 1, 2):
                x_start = max(0, int(intersections[j]))
                x_end = min(size - 1, int(intersections[j + 1]))
                for x in range(x_start, x_end + 1):
                    set_pixel(x, y, r, g, b)
    
    # Draw background
    for y in range(size):
        for x in range(size):
            if in_rounded_rect(x, y, size, size, corner_radius):
                set_pixel(x, y, *bg)
    
    # Draw lightning bolt ⚡
    cx, cy = size / 2, size / 2
    
    # Lightning bolt polygon points (designed at 1024, scaled)
    # Main bolt shape
    bolt = [
        (cx - 30*s,  cy - 380*s),   # top point
        (cx + 180*s, cy - 380*s),   # top right
        (cx + 40*s,  cy - 40*s),    # middle right notch
        (cx + 200*s, cy - 40*s),    # middle far right
        (cx + 30*s,  cy + 400*s),   # bottom point
        (cx - 60*s,  cy + 30*s),    # middle left notch  
        (cx - 200*s, cy + 30*s),    # middle far left
    ]
    
    fill_polygon(bolt, *blue)
    
    # Add a lighter highlight stripe on the left face of the bolt
    highlight = [
        (cx - 30*s,  cy - 380*s),
        (cx + 70*s,  cy - 380*s),
        (cx - 70*s,  cy - 40*s),
        (cx - 200*s, cy + 30*s),
        (cx - 120*s, cy + 30*s),
        (cx + 30*s,  cy - 40*s),
    ]
    fill_polygon(highlight, *light_blue)
    
    # Small glow effect: slightly larger bolt behind with lower alpha
    # (skip for simplicity — the solid bolt looks clean enough)
    
    return pixels

def main():
    os.makedirs('AppIcon.iconset', exist_ok=True)
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for sz in sizes:
        print(f"  Generating {sz}x{sz}...")
        px = draw_icon(sz)
        png_data = create_png(sz, sz, px)
        if sz <= 512:
            with open(f'AppIcon.iconset/icon_{sz}x{sz}.png', 'wb') as f:
                f.write(png_data)
        if sz >= 32:
            half = sz // 2
            with open(f'AppIcon.iconset/icon_{half}x{half}@2x.png', 'wb') as f:
                f.write(png_data)
    print("  Converting to .icns...")
    subprocess.run(['iconutil', '-c', 'icns', 'AppIcon.iconset', '-o', 'AppIcon.icns'], check=True)
    print("✅ AppIcon.icns generated!")

if __name__ == '__main__':
    main()
