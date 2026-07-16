import base64
import io
import logging
import sys
import threading
import time
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


# ---------------------------------------------------------------------------
# Display geometry / scale factor
# ---------------------------------------------------------------------------

_SCALE_CACHE_TTL = 5.0
_scale_lock = threading.Lock()
_scale_cache: Dict[str, Tuple[float, float]] = {}


def _cached_value(name: str, compute):
    """Return a cached value, recomputing if older than the TTL."""
    now = time.time()
    with _scale_lock:
        value, timestamp = _scale_cache.get(name, (None, 0))
        if value is not None and now - timestamp < _SCALE_CACHE_TTL:
            return value
    value = compute()
    with _scale_lock:
        _scale_cache[name] = (value, now)
    return value


def _scale_factor_impl() -> float:
    try:
        import Quartz
        main_id = Quartz.CGMainDisplayID()
        bounds = Quartz.CGDisplayBounds(main_id)
        pixel_width = Quartz.CGDisplayPixelsWide(main_id)
        return pixel_width / bounds.size.width
    except Exception as e:
        logger.debug(f"Could not determine scale factor: {e}")
        return 1.0


def scale_factor() -> float:
    """Return the primary display scale factor, cached for a few seconds."""
    return _cached_value("scale_factor", _scale_factor_impl)


# ---------------------------------------------------------------------------
# Screenshot capture (reuses a single MSS instance)
# ---------------------------------------------------------------------------

_mss_lock = threading.RLock()
_mss_instance: mss.MSS = None
_mss_created = 0.0
_MSS_TTL = 30.0


def _get_mss() -> mss.MSS:
    """Return a long-lived mss instance, recreating it periodically so display changes are picked up."""
    global _mss_instance, _mss_created
    now = time.time()
    if _mss_instance is None or now - _mss_created > _MSS_TTL:
        if _mss_instance is not None:
            try:
                _mss_instance.close()
            except Exception:
                pass
        _mss_instance = mss.mss()
        _mss_created = now
    return _mss_instance


def list_displays() -> list:
    """Return list of display dicts with physical pixel dimensions."""
    displays = []
    with _mss_lock:
        sct = _get_mss()
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
    """Capture a screenshot and return a PIL Image and monitor metadata."""
    with _mss_lock:
        sct = _get_mss()
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
    """Resize image to fit within max_dim while keeping aspect ratio.

    Uses bilinear resampling for speed; quality loss is negligible for
    model-sized screenshots.
    """
    if max(img.width, img.height) <= max_dim:
        return img
    scale = max_dim / max(img.width, img.height)
    new_size = (int(img.width * scale), int(img.height * scale))
    return img.resize(new_size, Image.Resampling.BILINEAR)


def image_to_base64(img: Image.Image, fmt: str = "PNG", quality: int = 80) -> str:
    buf = io.BytesIO()
    if fmt.upper() == "JPEG":
        img = img.convert("RGB")
        img.save(buf, format="JPEG", quality=quality)
    else:
        img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def _click_scale_impl(max_screenshot_dim: int) -> float:
    with _mss_lock:
        sct = _get_mss()
        monitor = sct.monitors[0]
        max_dim = max(monitor["width"], monitor["height"])
    if max_dim <= max_screenshot_dim:
        return 1.0
    return max_dim / max_screenshot_dim


def click_scale_for_all_screens(max_screenshot_dim: int) -> float:
    """Return the ratio of physical screen pixels to model screenshot pixels."""
    key = f"click_scale:{max_screenshot_dim}"
    return _cached_value(key, lambda: _click_scale_impl(max_screenshot_dim))


def scale_to_physical(x: int, y: int, scale: float) -> Tuple[int, int]:
    return int(x * scale), int(y * scale)


def scale_to_logical(x: int, y: int, scale: float) -> Tuple[int, int]:
    return int(x / scale), int(y / scale)


def clamp(n: int, min_val: int, max_val: int) -> int:
    return max(min_val, min(n, max_val))
