import base64
import io
import logging
import sys
from pathlib import Path
from typing import Dict, Tuple

import mss
from PIL import Image


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger("mcp-computer-use")


def get_logger(name: str = "mcp-computer-use"):
    return logging.getLogger(name)


def get_logger_file_path(log_dir: Path) -> Path:
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir / "server.log"


def setup_logging(log_dir: Path, level: str = "INFO"):
    log_dir.mkdir(parents=True, exist_ok=True)
    file_path = log_dir / "server.log"
    handler = logging.FileHandler(file_path)
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s"))

    root = logging.getLogger()
    root.setLevel(level)
    for h in root.handlers[:]:
        root.removeHandler(h)
    root.addHandler(handler)
    root.addHandler(logging.StreamHandler(sys.stderr))


def scale_factor() -> float:
    """Return the primary display scale factor (1.0 for non-Retina, 2.0 for Retina)."""
    try:
        import Quartz
        main_id = Quartz.CGMainDisplayID()
        bounds = Quartz.CGDisplayBounds(main_id)
        pixel_width = Quartz.CGDisplayPixelsWide(main_id)
        return pixel_width / bounds.size.width
    except Exception as e:
        logger.debug(f"Could not determine scale factor: {e}")
        return 1.0


def list_displays() -> list:
    """Return list of display dicts with physical pixel dimensions."""
    displays = []
    with mss.MSS() as sct:
        for i, monitor in enumerate(sct.monitors[1:], start=1):
            displays.append(
                {
                    "index": i,
                    "left": monitor["left"],
                    "top": monitor["top"],
                    "width": monitor["width"],
                    "height": monitor["height"],
                }
            )
    return displays


def capture(display: int = 0, region: Tuple[int, int, int, int] = None) -> Tuple[Image.Image, Dict]:
    """Capture a screenshot and return PIL Image and monitor metadata."""
    with mss.MSS() as sct:
        if region:
            left, top, width, height = region
            monitor = {"left": left, "top": top, "width": width, "height": height}
        elif display == 0:
            monitor = sct.monitors[0]  # all screens
        else:
            try:
                monitor = sct.monitors[display]
            except IndexError:
                raise ValueError(f"Display {display} not found. Available: {len(sct.monitors) - 1}")
        sct_img = sct.grab(monitor)
        img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
    return img, monitor


def resize_for_model(img: Image.Image, max_dim: int) -> Image.Image:
    """Resize image to fit within max_dim while keeping aspect ratio."""
    if max(img.width, img.height) <= max_dim:
        return img
    scale = max_dim / max(img.width, img.height)
    new_size = (int(img.width * scale), int(img.height * scale))
    return img.resize(new_size, Image.Resampling.LANCZOS)


def image_to_base64(img: Image.Image, fmt: str = "PNG", quality: int = 80) -> str:
    buf = io.BytesIO()
    if fmt.upper() == "JPEG":
        img = img.convert("RGB")
        img.save(buf, format="JPEG", quality=quality)
    else:
        img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def click_scale_for_all_screens(max_screenshot_dim: int) -> float:
    """Return the ratio of physical screen pixels to model screenshot pixels."""
    with mss.MSS() as sct:
        monitor = sct.monitors[0]
        max_dim = max(monitor["width"], monitor["height"])
    if max_dim <= max_screenshot_dim:
        return 1.0
    return max_dim / max_screenshot_dim


def scale_to_physical(x: int, y: int, scale: float) -> Tuple[int, int]:
    return int(x * scale), int(y * scale)


def scale_to_logical(x: int, y: int, scale: float) -> Tuple[int, int]:
    return int(x / scale), int(y / scale)


def clamp(n: int, min_val: int, max_val: int) -> int:
    return max(min_val, min(n, max_val))
