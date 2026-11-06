"""Rebuild bundled Latin/Cyrillic paper font subsets from DejaVu Sans 2.37.
Usage: python tools/build_paper_font.py /path/to/dejavu
Requires fonttools; runtime Godot does not require Python.
See assets/fonts/LICENSE.txt for the source font license.
"""
from pathlib import Path
import sys
from fontTools import subset
from fontTools.ttLib import TTFont

source = Path(sys.argv[1])
destination = Path(__file__).resolve().parents[1] / 'assets/fonts'
unicodes = set(range(0x20, 0x7f)) | set(range(0x400, 0x500)) | set(range(0x2000, 0x2040)) | set(range(0x2190, 0x2195))
for style in ['Regular', 'Bold']:
    original = 'DejaVuSans.ttf' if style == 'Regular' else 'DejaVuSans-Bold.ttf'
    font = TTFont(source / original)
    options = subset.Options()
    options.name_IDs = ['*']
    builder = subset.Subsetter(options=options)
    builder.populate(unicodes=unicodes)
    builder.subset(font)
    names = {1: 'Coffee Shift Paper', 2: style, 4: 'Coffee Shift Paper ' + style, 6: 'CoffeeShiftPaper-' + style}
    for record in font['name'].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    font.save(destination / ('paper_' + style.lower() + '.ttf'))
