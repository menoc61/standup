"""Regenerate every platform app icon from the single brand asset.

Why this exists
---------------
The Android launcher icon had been replaced with the CSPH mark, but the web and
macOS icons were still the stock Flutter logo. Two platforms shipping different
icons for the same app is a branding bug, and it is invisible in a code review
because each file just looks like "a png".

Everything is derived from ``assets/branding/csph_standup_logo.png`` so the icons
cannot drift apart again: re-run this script after changing the brand asset.

Usage
-----
    python scripts/icons/generate_icons.py

Requires Pillow (``pip install pillow``).
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE = REPO_ROOT / "assets" / "branding" / "csph_standup_logo.png"

# Anything lighter than this is treated as empty background when measuring the
# artwork bounds. The source is a 24-bit RGB image with the white background
# baked in, so there is no alpha channel to threshold against.
BACKGROUND_THRESHOLD = 245

# Brand colour, mirroring AppColors.brand. Used only to fill the corner squares
# of the Windows tile, where leaving them white shows a white frame once Explorer
# masks the icon. Kept in step by `test/contrast_test.dart`, which asserts the
# same value against AppColors.brand.
BRAND = (4, 114, 177)

WHITE = (255, 255, 255)

# Linux desktop integration.
#
# GTK resolves `Icon=` in the .desktop entry against the installed icon theme by
# stem, ignoring the extension. Both the stem and the `Icon=` line are derived
# from this constant, so the entry can never name files that were not written.
ICON_STEM = "standup_app_icon"
DESKTOP_STEM = "standup_app"

DESKTOP_FILE = f"""[Desktop Entry]
Type=Application
Name=CSPH StandUp
GenericName=Wellbeing Reminder
Comment=Hourly stand-up and posture-break reminders with anonymised team analytics.
Exec={DESKTOP_STEM}
Icon={ICON_STEM}
Terminal=false
Categories=Utility;Health;
Keywords=wellbeing;health;posture;standup;ergonomics;
StartupNotify=true
StartupWMClass={DESKTOP_STEM}
"""


def artwork_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    """Return the bounding box of the non-white artwork.

    Scanned by sampling every fourth pixel: the mark is large and high contrast,
    so a coarse scan is both fast and exact to within a few pixels, which is then
    irrelevant once the result is resampled.
    """
    grey = image.convert("L")
    width, height = grey.size
    step = max(1, min(width, height) // 256)

    left, top = width, height
    right, bottom = 0, 0

    for y in range(0, height, step):
        for x in range(0, width, step):
            if grey.getpixel((x, y)) < BACKGROUND_THRESHOLD:
                if x < left:
                    left = x
                if x > right:
                    right = x
                if y < top:
                    top = y
                if y > bottom:
                    bottom = y

    if right <= left or bottom <= top:
        raise SystemExit(
            f"No artwork found in {SOURCE}. The asset may be blank or fully white."
        )

    return left, top, right + 1, bottom + 1


def build_tile(
    logo: Image.Image,
    size: int,
    *,
    inset: float = 0.0,
    background: tuple[int, int, int] = WHITE,
    round_corners: bool = False,
    rounded_colour: tuple[int, int, int] = BRAND,
) -> Image.Image:
    """Render the logo centred on a square background at ``size`` pixels.

    ``inset`` shrinks the artwork relative to the tile, which is what the maskable
    and Windows icons need: those are cropped by the launcher to shapes that can
    clip close to the edge, so the mark must sit well inside.
    """
    tile = Image.new("RGB", (size, size), background)

    crop = artwork_bbox(logo)
    mark = logo.crop(crop)

    # Fit the mark inside the drawable area, preserving its aspect ratio. The
    # mark is noticeably wider than it is tall, so the square ends up with more
    # space above and below than at the sides; that is correct rather than a
    # distortion to be corrected away.
    drawable = int(size * (1.0 - 2 * inset))
    if drawable <= 0:
        raise SystemError("inset leaves no room to draw the logo")

    scale = min(drawable / mark.width, drawable / mark.height)
    target = (max(1, round(mark.width * scale)), max(1, round(mark.height * scale)))
    resized = mark.resize(target, Image.LANCZOS)

    offset = ((size - target[0]) // 2, (size - target[1]) // 2)
    tile.paste(resized, offset)

    if round_corners:
        _apply_rounded_corners(tile, rounded_colour)

    return tile


def _apply_rounded_corners(image: Image.Image, colour: tuple[int, int, int]) -> None:
    """Paint the tile's four corner squares with ``colour``, in place.

    Windows renders a square icon inside a rounded container and darkens anything
    outside the mask, so leaving the corners white produces a visible white
    frame. Filling them with the brand colour keeps the tile reading as one
    shape at every size.
    """
    width, height = image.size
    pixels = image.load()
    radius = max(1, min(width, height) // 12)

    for corner_x, corner_y, x_dir, y_dir in (
        (0, 0, 1, 1),
        (width - 1, 0, -1, 1),
        (0, height - 1, 1, -1),
        (width - 1, height - 1, -1, -1),
    ):
        for dy in range(radius):
            for dx in range(radius):
                if (dx - radius) ** 2 + (dy - radius) ** 2 > radius**2:
                    x = corner_x + x_dir * dx
                    y = corner_y + y_dir * dy
                    pixels[x, y] = colour


def write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)
    print(f"  {path.relative_to(REPO_ROOT)}  ({image.width}x{image.height})")


def generate_web(logo: Image.Image) -> None:
    """PWA icons.

    The plain icons fill the tile because a browser tab has no cropping. The
    maskable variants are inset to 20% because Android crops a maskable icon to
    whatever shape the launcher chose, and a mark that touches the edge gets its
    own letters sliced off.
    """
    print("web")
    for size in (192, 512):
        write_png(build_tile(logo, size), REPO_ROOT / "web" / "icons" / f"Icon-{size}.png")
    for size in (192, 512):
        write_png(
            build_tile(logo, size, inset=0.20),
            REPO_ROOT / "web" / "icons" / f"Icon-maskable-{size}.png",
        )
    write_png(
        build_tile(logo, 64, inset=0.02),
        REPO_ROOT / "web" / "favicon.png",
    )


def generate_apple(logo: Image.Image) -> None:
    """macOS AppIcon set.

    macOS does not mask icons, so every tile is full bleed. It does, however,
    apply its own rounding on top, and it flattens transparency, hence the plain
    opaque tiles with no inset.
    """
    print("macOS")
    for size in (16, 32, 64, 128, 256, 512, 1024):
        path = (
            REPO_ROOT
            / "macos"
            / "Runner"
            / "Assets.xcassets"
            / "AppIcon.appiconset"
            / f"app_icon_{size}.png"
        )
        write_png(build_tile(logo, size), path)


def generate_windows(logo: Image.Image) -> None:
    """Windows .ico.

    Written as a multi-size icon rather than a single 256px frame so Explorer,
    the taskbar and the Alt-Tab switcher each pick a native resolution instead
    all scaling the same bitmap.
    """
    print("Windows")
    sizes = (16, 24, 32, 48, 64, 128, 256)
    images = [
        build_tile(logo, size, inset=0.04, round_corners=True) for size in sizes
    ]
    path = REPO_ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    images[-1].save(path, "ICO", sizes=[(s, s) for s in sizes])
    print(f"  {path.relative_to(REPO_ROOT)}  ({', '.join(str(s) for s in sizes)})")


def generate_android_foreground(logo: Image.Image) -> None:
    """Android adaptive-icon layers.

    Android renders the foreground inside a mask and then scales it up by 1.5x,
    so the artwork must be inset by a third to survive being cropped to a circle.
    The background is supplied separately as a flat colour, which is why only the
    foreground and monochrome layers are generated here.

    The monochrome layer is the same silhouette reduced to an alpha mask. Android
    13 tints this layer to the user's wallpaper palette; if it is absent the app
    silently opts out of themed icons.
    """
    print("Android adaptive layers")
    buckets = (("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432))

    for bucket, size in buckets:
        base = (
            REPO_ROOT
            / "android"
            / "app"
            / "src"
            / "main"
            / "res"
            / f"mipmap-{bucket}"
        )

        write_png(build_tile(logo, size, inset=0.28), base / "ic_launcher_foreground.png")
        write_png(
            build_monochrome(logo, size, inset=0.28),
            base / "ic_launcher_monochrome.png",
        )


def build_monochrome(
    logo: Image.Image, size: int, *, inset: float = 0.0
) -> Image.Image:
    """Render the mark as a transparent silhouette for themed icons.

    Any pixel that is not background becomes fully opaque black; Android replaces
    that black with the theme colour. Keeping the alpha shape faithful to the
    artwork is the whole point, so this uses the same measured bounds as the
    colour layers and differs only in how the interior is filled.
    """
    crop = artwork_bbox(logo)
    mark = logo.crop(crop)

    drawable = int(size * (1.0 - 2 * inset))
    scale = min(drawable / mark.width, drawable / mark.height)
    target = (max(1, round(mark.width * scale)), max(1, round(mark.height * scale)))

    grey = mark.convert("L").resize(target, Image.LANCZOS)
    alpha = grey.point(lambda v: 0 if v >= BACKGROUND_THRESHOLD else 255, mode="L")

    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    solid = Image.new("RGBA", target, (0, 0, 0, 255))
    tile.paste(solid, ((size - target[0]) // 2, (size - target[1]) // 2), alpha)

    return tile


def generate_widget_logos(logo: Image.Image) -> None:
    """The logo shown *inside* the home-screen widget, on each platform.

    ## Why these are generated rather than left alone

    The launcher icons were regenerated for the rebrand but these two were not,
    so the app drawer showed the new mark while the widget itself still showed
    the retired wordmark. They are separate files with separate lifecycles, which
    is exactly why they drift.

    Both are square, opaque and 1024px: the widget renders them as a small chip
    inside a rounded container, and a small bitmap scaled up shows its blur. The
    artwork is inset a little so it does not touch the chip's rounded edge.
    """
    print("Widget logos")
    write_png(
        build_tile(logo, 1024, inset=0.06),
        REPO_ROOT
        / "android"
        / "app"
        / "src"
        / "main"
        / "res"
        / "drawable-nodpi"
        / "standup_logo.png",
    )
    write_png(
        build_tile(logo, 1024, inset=0.06),
        REPO_ROOT
        / "ios"
        / "StandUpWidget"
        / "Assets.xcassets"
        / "standup_logo.imageset"
        / "standup_logo.png",
    )


def generate_linux(logo: Image.Image) -> None:
    """Linux desktop icons and the `.desktop` entry.

    The Linux runner was added without any of the template's icon assets, so the
    window had no icon and there was no `.desktop` file for a desktop
    environment to map the binary to. Both are generated here so they cannot
    drift either.

    The `.desktop` file is written by this script rather than committed by hand
    because it must name the same icon stem as the PNGs below, and a mismatch
    between the two is invisible until someone installs the app.
    """
    print("Linux")
    assets = REPO_ROOT / "linux" / "assets" / "icons"

    for size in (16, 24, 32, 48, 64, 128, 256, 512):
        write_png(build_tile(logo, size, round_corners=True), assets / f"{ICON_STEM}_{size}.png")

    (REPO_ROOT / "linux" / "runner" / f"{DESKTOP_STEM}.desktop").write_text(
        DESKTOP_FILE, encoding="utf-8"
    )
    print(f"  linux/runner/{DESKTOP_STEM}.desktop")


def main() -> int:
    if not SOURCE.exists():
        print(f"Brand asset missing: {SOURCE}", file=sys.stderr)
        return 1

    logo = Image.open(SOURCE)
    print(f"Source: {SOURCE.relative_to(REPO_ROOT)} ({logo.width}x{logo.height})\n")

    generate_web(logo)
    generate_apple(logo)
    generate_windows(logo)
    generate_android_foreground(logo)
    generate_widget_logos(logo)
    generate_linux(logo)

    print("\nDone. Re-run after any change to the brand asset.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())