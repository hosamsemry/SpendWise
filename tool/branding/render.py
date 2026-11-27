#!/usr/bin/env python3
"""Render Paydial launcher icons, splash and logo PNGs from the SVG sources.

Needs Google Chrome (headless) and ImageMagick 6 (`convert`) on PATH.
Run from anywhere:  python3 tool/branding/render.py
"""
import pathlib
import subprocess
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RES = ROOT / "android/app/src/main/res"
IMAGES = ROOT / "assets/images"
FONT = ROOT / "assets/fonts/Outfit-ExtraBold.ttf"

TILE = "#0D5A4E"  # deep pine icon tile
WORDMARK = "#2E8C7A"  # mid pine: readable on the light (#F6F6F3) and dark (#1A1D20) splash

MARK = (HERE / "mark.svg").read_text()
MARK_MONO = (HERE / "mark_mono.svg").read_text()


def svg_body(svg: str) -> str:
    """Inner shapes of a 108-unit mark, for nesting in a composition."""
    return svg.split(">", 1)[1].rsplit("</svg>", 1)[0]


def scaled(svg: str, scale: float) -> str:
    return f'<g transform="translate(54 54) scale({scale}) translate(-54 -54)">{svg_body(svg)}</g>'


def square(inner: str, bg: str = "") -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">{bg}{inner}</svg>'


def badge(scale: float = 1.4) -> str:
    """Mark on an pine disc, so it reads on light and dark screens."""
    return f'<circle cx="54" cy="54" r="54" fill="{TILE}"/>{scaled(MARK, scale)}'


def html(svg: str, w: int, h: int, extra: str = "") -> str:
    return f"""<!doctype html><html><head><style>
@font-face{{font-family:Outfit;font-weight:800;src:url('{FONT.as_uri()}')}}
html,body{{margin:0;background:transparent;width:{w}px;height:{h}px;overflow:hidden}}
</style></head><body>{svg}{extra}</body></html>"""


def lockup(w: int, h: int, badge_px: int, font_px: int, gap: int) -> str:
    total = badge_px + gap + font_px
    top = (h - total) // 2
    return html(
        f'<svg style="position:absolute;left:{(w - badge_px) // 2}px;top:{top}px" width="{badge_px}" height="{badge_px}" '
        f'xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">{badge()}</svg>',
        w, h,
        f'<div style="position:absolute;left:0;right:0;top:{top + badge_px + gap}px;text-align:center;'
        f'font:800 {font_px}px/1 Outfit;letter-spacing:-0.01em;color:{WORDMARK}">Paydial</div>',
    )


def render(page: str, w: int, h: int, out: pathlib.Path, tmp: pathlib.Path) -> None:
    src = tmp / f"{out.stem}.html"
    src.write_text(page)
    subprocess.run(
        ["google-chrome", "--headless", "--disable-gpu", "--hide-scrollbars",
         "--default-background-color=00000000", f"--window-size={w},{h}",
         f"--screenshot={out}", src.as_uri()],
        check=True, capture_output=True,
    )


def resize(src: pathlib.Path, dest: pathlib.Path, w: int, h: int | None = None) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["convert", str(src), "-filter", "Lanczos", "-resize", f"{w}x{h or w}!",
                    "-strip", str(dest)], check=True)


def main() -> None:
    big = 1296  # 12x the 108dp grid
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    with tempfile.TemporaryDirectory() as t:
        tmp = pathlib.Path(t)

        # Adaptive foreground (108dp, transparent; background colour is in values/colors.xml).
        fg = tmp / "fg.png"
        render(html(square(svg_body(MARK)).replace("<svg ", f'<svg width="{big}" height="{big}" ', 1), big, big), big, big, fg, tmp)

        # Themed-icon monochrome layer: white shapes, alpha from luminance.
        mono_raw = tmp / "mono_raw.png"
        render(html(square(svg_body(MARK_MONO), '<rect width="108" height="108" fill="#000"/>')
                    .replace("<svg ", f'<svg width="{big}" height="{big}" ', 1), big, big), big, big, mono_raw, tmp)
        mono = tmp / "mono.png"
        subprocess.run(["convert", str(mono_raw), "-colorspace", "gray", "-alpha", "copy",
                        "-fill", "white", "-colorize", "100", str(mono)], check=True)

        # Legacy (pre-Android 8) icon: rounded pine tile, mark enlarged since it isn't masked.
        tile = f'<rect x="4" y="4" width="100" height="100" rx="23" fill="{TILE}"/>'
        legacy = tmp / "legacy.png"
        render(html(square(scaled(MARK, 1.3), tile).replace("<svg ", f'<svg width="{big}" height="{big}" ', 1), big, big), big, big, legacy, tmp)

        emblem = tmp / "emblem.png"
        render(html(square(badge()).replace("<svg ", f'<svg width="{big}" height="{big}" ', 1), big, big), big, big, emblem, tmp)

        splash = tmp / "splash.png"
        render(lockup(1920, 1920, 820, 300, 110), 1920, 1920, splash, tmp)

        logo = tmp / "logo.png"
        render(lockup(2052, 1425, 780, 270, 90), 2052, 1425, logo, tmp)

        for name, d in densities.items():
            resize(fg, RES / f"mipmap-{name}/ic_launcher_foreground.png", round(108 * d))
            resize(mono, RES / f"mipmap-{name}/ic_launcher_monochrome.png", round(108 * d))
            resize(legacy, RES / f"mipmap-{name}/ic_launcher.png", round(48 * d))
        for folder, px in {"drawable": 240, "drawable-hdpi": 240, "drawable-xhdpi": 320,
                           "drawable-xxhdpi": 480, "drawable-xxxhdpi": 640}.items():
            resize(splash, RES / folder / "launch_image.png", px)

        resize(fg, IMAGES / "app_icon_fg_432.png", 432)
        resize(legacy, IMAGES / "app_icon_192.png", 192)
        resize(legacy, IMAGES / "app_icon.png", 512)
        resize(emblem, IMAGES / "logo_emblem.png", 512)
        resize(splash, IMAGES / "splash_logo.png", 480)
        resize(logo, IMAGES / "logo.png", 684, 475)
    print("done")


if __name__ == "__main__":
    main()
