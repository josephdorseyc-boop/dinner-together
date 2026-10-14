"""Supplemental geometry model; does not replace native XCUI verification."""
def choose(y, origin, height, zone, buttons, bounded=True):
    for x in (.5, .12, .88):
        for dy in (y, y-.08, y+.08, y-.16, y+.16):
            if not .1 < dy < .9: continue
            py=origin+height*dy
            if bounded and not zone[0]+12 <= py <= zone[1]-12: continue
            if not any(a <= x <= b and c <= py <= d for a,b,c,d in buttons):
                return x,dy
    return (.5, ((sum(zone)/2)-origin)/height) if bounded else (.5,y)

# AX-like geometry with lower pinned caption. The button blocker forces the
# original center-column search to .71; the bounded helper uses a safe margin.
case=(.55,0,852,(60,550),[(.2,.8,300,550)])
assert choose(*case,bounded=False)[0] == .5
assert abs(choose(*case,bounded=False)[1] - .71) < 1e-9
assert choose(*case)==(.12,.55)
# Fallback when every point is covered still remains above the pinned bar.
for origin,height,zone in ((0,852,(60,550)),(20,852,(80,570)),(0,1194,(60,1064))):
    x,y=choose(.55,origin,height,zone,[(0,1,origin,origin+height)])
    assert zone[0] < origin+height*y < zone[1]
# Original behavior remains for a fully clear ordinary screen.
assert choose(.55,0,852,(60,722),[])==(.5,.55)
print("5 supplemental geometry scenarios passed")
