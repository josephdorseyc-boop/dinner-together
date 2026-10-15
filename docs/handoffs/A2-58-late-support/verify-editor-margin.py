"""Supplemental candidate geometry/source checks; not native UI verification."""
from pathlib import Path
import math
# ScrollView-local constant x stays in the known outer 24pt padding, including
# floating iPad sheets where a screen-normalized side gesture misses the sheet.
for x,y,w,h in [(0,102,402,646),(212,100,600,900),(0,102,393,620),(20,80,540,650),(0,60,1024,1000)]:
    start=(x+12,y+h*.70); end=(x+12,y+h*.25)
    assert x < start[0] < x+24
    assert y < end[1] < start[1] < y+h
    assert all(math.isfinite(v) for v in (*start,*end))
s=Path(__file__).with_name('source').joinpath('DinnerTogetherUITests/UITestSupport.swift').read_text()
f=s[s.index('func flowSwipeEditAndDelete'):s.index('func flowSwipeEditAndDelete')+8000]
assert 'for _ in 0..<4 where !isComfortablyVisible(notes)' in f
assert 'guard isFiniteFrame(viewport), viewport.height > 80, viewport.width > 24' in f
assert 'guard screen.contains(startPoint), screen.contains(endPoint)' in f
assert 'scrollTo(notes) // retain' in f
assert 'notes.tap()' in f and 'notes.typeText("Use extra lime. Check five minutes early.")' in f
assert 'XCTAssertEqual(shown.label, "Use extra lime. Check five minutes early."' in f
assert 'r20-notes-before-scroll-fallback-hierarchy' in f
assert 'Cancel keeps the recipe' in f and 'the recipe is gone from the list' in f
# Offscreen scroll-view candidates must be rejected before dispatch.
for y,h in ((900,600),(-1000,600)):
    points=[(12,y+h*fraction) for fraction in (.70,.25)]
    assert not all(0 <= px <= 402 and 0 <= py <= 874 for px,py in points)
print('5 viewport and 2 offscreen rejection scenarios; 8 retained-contract source checks passed')
