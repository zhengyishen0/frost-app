#!/usr/bin/env python3
"""
Generate Frost app icon: white snowflake on black rounded square
Run: python3 scripts/generate_icon.py
"""

import os
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Please install Pillow: pip3 install Pillow")
    exit(1)

def draw_snowflake(draw, center_x, center_y, size, color):
    """Draw a simple 6-pointed snowflake, rotated 90 degrees so one arm points up"""
    import math

    # Smaller snowflake with more padding
    arm_length = size * 0.28  # Reduced from 0.4
    branch_length = size * 0.10  # Reduced from 0.15
    branch_offset = size * 0.14  # Reduced from 0.2
    line_width = max(1, int(size * 0.04))

    for i in range(6):
        # Add 90 degrees rotation so one arm points straight up
        angle = math.radians(i * 60 + 90)

        # Main arm
        end_x = center_x + arm_length * math.cos(angle)
        end_y = center_y - arm_length * math.sin(angle)
        draw.line([(center_x, center_y), (end_x, end_y)], fill=color, width=line_width)

        # Branches on each arm
        for branch_dir in [-1, 1]:
            branch_angle = angle + branch_dir * math.radians(45)
            branch_start_x = center_x + branch_offset * math.cos(angle)
            branch_start_y = center_y - branch_offset * math.sin(angle)
            branch_end_x = branch_start_x + branch_length * math.cos(branch_angle)
            branch_end_y = branch_start_y - branch_length * math.sin(branch_angle)
            draw.line([(branch_start_x, branch_start_y), (branch_end_x, branch_end_y)], fill=color, width=line_width)

def create_icon(size):
    """Create an icon of the given size"""
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw black rounded square (macOS squircle style)
    padding = int(size * 0.05)
    corner_radius = int(size * 0.22)  # ~22% for macOS style

    draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=corner_radius,
        fill='black'
    )

    # Draw white snowflake
    center = size // 2
    draw_snowflake(draw, center, center, size, 'white')

    return img

def main():
    # Output directory
    script_dir = Path(__file__).parent.parent
    main_iconset = script_dir / "Blurred" / "Assets.xcassets" / "AppIcon.appiconset"
    launcher_iconset = script_dir / "BlurredLauncher" / "Assets.xcassets" / "AppIcon.appiconset"

    sizes = [16, 32, 64, 128, 256, 512, 1024]

    for iconset in [main_iconset, launcher_iconset]:
        if not iconset.exists():
            print(f"Warning: {iconset} does not exist")
            continue

        print(f"Generating icons in {iconset}")
        for size in sizes:
            icon = create_icon(size)
            output_path = iconset / f"{size}.png"
            icon.save(output_path, 'PNG')
            print(f"  Created {size}x{size} icon")

    print("\nDone! Icon files have been generated.")

if __name__ == "__main__":
    main()
