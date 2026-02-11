#!/usr/bin/env python3
"""
Generate favicon.ico from an SVG logo without native cairo dependencies.

This script supports a practical SVG subset used by this project logo:
- <path d="..."> with commands: M, L, H, V, Z (uppercase/lowercase)
- fill colors in hex format (#RRGGBB or #RGB)

Install requirement:
  pip install Pillow
"""
from __future__ import annotations

import io
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Install Pillow: pip install Pillow")
    sys.exit(1)

# Favicon sizes (browsers use 16, 32; some use 48)
FAVICON_SIZES = [16, 32, 48]

_TOKEN_RE = re.compile(r"[MmLlHhVvZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?")


def _parse_view_box(svg_root: ET.Element) -> tuple[float, float]:
    view_box = svg_root.attrib.get("viewBox")
    if view_box:
        parts = view_box.replace(",", " ").split()
        if len(parts) == 4:
            return float(parts[2]), float(parts[3])
    width = float(svg_root.attrib.get("width", "24"))
    height = float(svg_root.attrib.get("height", "24"))
    return width, height


def _parse_hex_color(value: str | None) -> tuple[int, int, int, int]:
    if not value:
        return (0, 0, 0, 255)
    v = value.strip()
    if v.startswith("#"):
        if len(v) == 4:  # #RGB
            r = int(v[1] * 2, 16)
            g = int(v[2] * 2, 16)
            b = int(v[3] * 2, 16)
            return (r, g, b, 255)
        if len(v) == 7:  # #RRGGBB
            r = int(v[1:3], 16)
            g = int(v[3:5], 16)
            b = int(v[5:7], 16)
            return (r, g, b, 255)
    # Fallback: black
    return (0, 0, 0, 255)


def _parse_path_polygons(path_d: str) -> list[list[tuple[float, float]]]:
    tokens = _TOKEN_RE.findall(path_d)
    polygons: list[list[tuple[float, float]]] = []
    i = 0
    cmd = None
    x = y = 0.0
    start_x = start_y = 0.0
    current_poly: list[tuple[float, float]] = []

    def read_num() -> float:
        nonlocal i
        if i >= len(tokens):
            raise ValueError("Unexpected end of path data")
        token = tokens[i]
        if re.fullmatch(r"[MmLlHhVvZz]", token):
            raise ValueError("Expected number, found command")
        i += 1
        return float(token)

    while i < len(tokens):
        token = tokens[i]
        if re.fullmatch(r"[MmLlHhVvZz]", token):
            cmd = token
            i += 1
        elif cmd is None:
            raise ValueError("Path data must start with command")

        if cmd in ("M", "m"):
            nx = read_num()
            ny = read_num()
            if cmd == "m":
                x += nx
                y += ny
            else:
                x, y = nx, ny
            if current_poly:
                polygons.append(current_poly)
            current_poly = [(x, y)]
            start_x, start_y = x, y
            # Subsequent coordinate pairs are implicit line commands
            cmd = "L" if cmd == "M" else "l"
        elif cmd in ("L", "l"):
            nx = read_num()
            ny = read_num()
            if cmd == "l":
                x += nx
                y += ny
            else:
                x, y = nx, ny
            current_poly.append((x, y))
        elif cmd in ("H", "h"):
            nx = read_num()
            x = x + nx if cmd == "h" else nx
            current_poly.append((x, y))
        elif cmd in ("V", "v"):
            ny = read_num()
            y = y + ny if cmd == "v" else ny
            current_poly.append((x, y))
        elif cmd in ("Z", "z"):
            if current_poly:
                current_poly.append((start_x, start_y))
                polygons.append(current_poly)
                current_poly = []
            cmd = None
        else:
            raise ValueError(f"Unsupported SVG path command: {cmd}")

    if current_poly:
        polygons.append(current_poly)
    return polygons


def _render_svg_paths_to_image(svg_path: Path, size: int) -> Image.Image:
    tree = ET.parse(svg_path)
    root = tree.getroot()

    vb_w, vb_h = _parse_view_box(root)
    if vb_w <= 0 or vb_h <= 0:
        raise ValueError("Invalid SVG viewBox/size")

    scale = min(size / vb_w, size / vb_h)
    x_off = (size - vb_w * scale) / 2.0
    y_off = (size - vb_h * scale) / 2.0

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Handle SVG namespace if present
    for elem in root.iter():
        if not elem.tag.endswith("path"):
            continue
        path_d = elem.attrib.get("d")
        if not path_d:
            continue
        fill = _parse_hex_color(elem.attrib.get("fill"))
        polygons = _parse_path_polygons(path_d)
        for poly in polygons:
            if len(poly) < 3:
                continue
            points = [(x_off + px * scale, y_off + py * scale) for px, py in poly]
            draw.polygon(points, fill=fill)
    return img


def svg_to_png_bytes(svg_path: Path, size: int) -> bytes:
    img = _render_svg_paths_to_image(svg_path, size)
    out = io.BytesIO()
    img.save(out, format="PNG")
    return out.getvalue()


def create_ico(png_bytes_list: list[bytes], sizes: list[int], output_path: Path) -> None:
    """Write multi-size ICO file (header + directory + PNG payloads)."""
    ico = bytearray()
    ico += struct.pack("<HHH", 0, 1, len(sizes))
    offset = 6 + 16 * len(sizes)
    for size, png_data in zip(sizes, png_bytes_list):
        w = size if size < 256 else 0
        h = size if size < 256 else 0
        ico += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(png_data), offset)
        offset += len(png_data)
    for png_data in png_bytes_list:
        ico += png_data
    output_path.write_bytes(ico)


def _resolve_default_svg(repo_root: Path) -> Path:
    preferred = repo_root / "assets" / "HyperlinksSpace.svg"
    previous = repo_root / "assets" / "images" / "loga.svg"
    legacy = repo_root / "assets" / "images" / "logo.svg"
    if preferred.exists():
        return preferred
    if previous.exists():
        return previous
    return legacy


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    svg_path = _resolve_default_svg(repo_root)
    output_paths = [
        repo_root / "assets" / "favicon.ico",
        repo_root / "web" / "favicon.ico",
    ]

    if len(sys.argv) >= 2:
        svg_path = Path(sys.argv[1])
    if len(sys.argv) >= 3:
        output_paths = [Path(p) for p in sys.argv[2:]]

    if not svg_path.exists():
        print(f"SVG not found: {svg_path}")
        sys.exit(1)

    try:
        png_list = [svg_to_png_bytes(svg_path, size) for size in FAVICON_SIZES]
    except Exception as exc:
        print(f"Error rendering SVG to favicon: {exc}")
        sys.exit(1)

    for ico_path in output_paths:
        ico_path.parent.mkdir(parents=True, exist_ok=True)
        create_ico(png_list, FAVICON_SIZES, ico_path)
        print(f"Created {ico_path} (sizes: {FAVICON_SIZES})")


if __name__ == "__main__":
    main()
