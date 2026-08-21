#!/usr/bin/env python3
"""Force Sparkle appcast marketing/build versions to match the GitHub release.

generate_appcast reads CFBundleShortVersionString from the archive and can
cache a stale 1.0.0. The EdDSA signature covers the enclosure file, not these
XML fields, so rewriting them is safe.
"""

from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
NSMAP = {"sparkle": SPARKLE_NS}


def local_name(tag: str) -> str:
    if tag.startswith("{") and "}" in tag:
        return tag.split("}", 1)[1]
    return tag


def set_sparkle_text(parent: ET.Element, name: str, value: str) -> None:
    qualified = f"{{{SPARKLE_NS}}}{name}"
    element = parent.find(f"sparkle:{name}", NSMAP)
    if element is None:
        element = parent.find(name)
    if element is None:
        element = ET.SubElement(parent, qualified)
    element.text = value


def sync_appcast(path: str, version: str, build: str, enclosure_filename: str) -> None:
    ET.register_namespace("sparkle", SPARKLE_NS)
    tree = ET.parse(path)
    root = tree.getroot()
    items = root.findall("./channel/item")
    if not items:
        raise SystemExit(f"{path} contains no appcast items")

    latest = items[0]
    title = latest.find("title")
    if title is not None:
        title.text = version
    set_sparkle_text(latest, "version", build)
    set_sparkle_text(latest, "shortVersionString", version)

    enclosure = latest.find("enclosure")
    if enclosure is None:
        raise SystemExit(f"{path} item is missing an enclosure")
    url = enclosure.get("url") or ""
    if enclosure_filename not in url:
        raise SystemExit(
            f"enclosure url {url!r} does not contain {enclosure_filename!r}"
        )

    tree.write(path, encoding="utf-8", xml_declaration=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--appcast", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--enclosure-filename", required=True)
    args = parser.parse_args()
    sync_appcast(args.appcast, args.version, args.build, args.enclosure_filename)
    print(
        f"Synced appcast {args.appcast} to {args.version} "
        f"(build {args.build}, {args.enclosure_filename})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
