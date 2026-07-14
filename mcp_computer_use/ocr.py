"""OCR helpers for locating text on the screen."""

import re
from typing import List

import pytesseract
from PIL import Image


def ocr_image(img: Image.Image) -> str:
    """Return all text recognized in the image."""
    return pytesseract.image_to_string(img)


def find_text(img: Image.Image, text: str) -> List[dict]:
    """Return bounding boxes for all occurrences of text in the image.

    Coordinates are relative to the image. The image is the screenshot that
    the model has been grounded on, so the returned coordinates are in the
    same model-sized space.
    """
    data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
    matches = []
    n_boxes = len(data["text"])
    pattern = re.compile(re.escape(text), re.IGNORECASE)

    for i in range(n_boxes):
        word = data["text"][i].strip()
        if pattern.search(word):
            matches.append(
                {
                    "text": word,
                    "left": data["left"][i],
                    "top": data["top"][i],
                    "width": data["width"][i],
                    "height": data["height"][i],
                    "center_x": data["left"][i] + data["width"][i] // 2,
                    "center_y": data["top"][i] + data["height"][i] // 2,
                    "confidence": data["conf"][i],
                }
            )
    return matches


def find_text_lines(img: Image.Image, text: str) -> List[dict]:
    """Line-level text search for longer phrases."""
    data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
    matches = []
    n_boxes = len(data["text"])
    pattern = re.compile(re.escape(text), re.IGNORECASE)

    # Tesseract output is grouped by block, par, line, word.
    # Group words by line number and join them.
    lines = {}
    for i in range(n_boxes):
        line_key = (data["block_num"][i], data["par_num"][i], data["line_num"][i])
        lines.setdefault(line_key, []).append({
            "text": data["text"][i],
            "left": data["left"][i],
            "top": data["top"][i],
            "width": data["width"][i],
            "height": data["height"][i],
            "conf": data["conf"][i],
        })

    for line_key, words in lines.items():
        words.sort(key=lambda w: w["left"])
        line_text = " ".join(w["text"] for w in words).strip()
        if pattern.search(line_text):
            left = min(w["left"] for w in words)
            top = min(w["top"] for w in words)
            right = max(w["left"] + w["width"] for w in words)
            bottom = max(w["top"] + w["height"] for w in words)
            matches.append(
                {
                    "text": line_text,
                    "left": left,
                    "top": top,
                    "width": right - left,
                    "height": bottom - top,
                    "center_x": (left + right) // 2,
                    "center_y": (top + bottom) // 2,
                }
            )
    return matches
