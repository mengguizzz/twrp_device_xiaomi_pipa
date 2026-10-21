#!/usr/bin/env python3
"""Keep only remove-project entries that match projects in the active manifest."""

from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: filter-minimal-manifest.py ACTIVE_MANIFEST "
            "REMOVE_MANIFEST OUTPUT_MANIFEST"
        )

    active_path, remove_path, output_path = map(Path, sys.argv[1:])
    active_root = ET.parse(active_path).getroot()
    active = {
        (project.get("path"), project.get("name"))
        for project in active_root.findall("project")
    }
    active_paths = {path for path, _ in active}
    active_names = {name for _, name in active}

    source_root = ET.parse(remove_path).getroot()
    output_root = ET.Element("manifest")
    kept = 0

    for removal in source_root.findall("remove-project"):
        path = removal.get("path")
        name = removal.get("name")
        if (path and path in active_paths) or (name and name in active_names):
            ET.SubElement(output_root, "remove-project", removal.attrib)
            kept += 1

    ET.indent(output_root, space="    ")
    output_path.write_text(
        ET.tostring(output_root, encoding="unicode") + "\n",
        encoding="utf-8",
    )
    print(
        f"Filtered recovery minimal manifest: {kept} projects removed, "
        f"{len(active_paths)} projects remain"
    )


if __name__ == "__main__":
    main()
