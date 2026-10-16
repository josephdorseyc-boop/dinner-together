"""Geometry equivalence and access-count model, not a native XCUI test."""
import random

def old(screen_max, target, bars):
    result=[]
    for exists, frame in bars:
        _,y,_,h=frame
        if exists and h>0 and y+h<=screen_max+1 and y>screen_max*.6 and frame!=target:
            result.append(y)
    return min(result,default=None)

def new(screen_max,target,bars):
    result=[]
    for exists,frame in bars:
        if not exists: continue
        _,y,_,h=frame
        if h<=0 or y+h>screen_max+1 or y<=screen_max*.6 or frame==target: continue
        result.append(y)
    return min(result,default=None)

random.seed(44)
for _ in range(10000):
    screen=random.choice([852,874,1194,1214])
    bars=[(random.choice([True,False]),(0,random.uniform(-100,screen+100),393,random.uniform(-20,200))) for _ in range(random.randrange(10))]
    target=random.choice([None]+[frame for _,frame in bars])
    assert old(screen,target,bars)==new(screen,target,bars)
# Explicit inclusive/strict edge tests, excluded target, hidden and zero bars.
for y,h in ((600,100),(600.0001,100),(900,101),(900,101.0001),(800,0)):
    bars=[(True,(0,y,393,h))]
    for target in (None,bars[0][1]):
        assert old(1000,target,bars)==new(1000,target,bars)
# Calls model: each qualifying bar formerly read frame 5 times and app.frame
# twice. The replacement reads one frame per bar and app.frame once/call.
for n in (1,2,4):
    assert (5*n+2*n)-(n+1)==6*n-1
print('10010 geometry cases passed; qualifying frame RPC model: 5/bar -> 1/bar; app.frame: 2/bar -> 1/call')
