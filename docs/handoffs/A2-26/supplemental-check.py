"""Narrow mirrors of inspected Swift branches, not native Swift/Vision execution."""
import re
from dataclasses import dataclass

@dataclass
class OCRLine:
    text: str
    top: float
    left: float = .06
    height: float = .015

TITLE = "Lavender-Ginger Meringue Twists"
tab_words = set("ingredients directions instructions method nutrition more notes reviews steps overview tips today news audio following search".split())
news_tabs = set("today audio following search".split())
exact = {"nutrition", "more", "scale", "cook", "save", "saved", "share", "start cooking", "read the story", "customize units", "recipe units are from the publisher", "in reminders", "print", "jump to recipe", "cook save share", "cook saved share", "show more", "see more", "notes", "reviews"}

def key(s):
    return re.sub(r"[^\w½¼¾⅓⅔⅛]+", " ", s.lower()).strip()

def is_chrome(k):
    if not k or re.fullmatch(r"\d{1,2} \d{2}", k) or re.fullmatch(r"\d{1,3}", k): return True
    if len(k) <= 2 and not re.search(r"\d", k): return True
    if k in exact or "grocery list" in k or k.startswith("add to grocery"): return True
    words=k.split()
    return (len(words)>=2 and all(w in tab_words for w in words)) or sum(w in news_tabs for w in words)>=2

def marker(s):
    m=re.fullmatch(r"\s*step\s*(\d{1,2})\s*[:.]?\s*", s, flags=re.I)
    return int(m.group(1)) if m else None

def screenshot_title(pages):
    counts={}
    for page in pages:
        ing=[l for l in page if key(l.text)=="ingredients"]
        dirs=[l for l in page if key(l.text) in {"directions","instructions","method"}]
        tab=next((a.top for a in ing if any(abs(a.top-b.top)<.012 for b in dirs)),None)
        top=[l for l in page if l.top<.16 and (tab is None or l.top<tab-.012) and not is_chrome(key(l.text))]
        if not top: continue
        joined=" ".join(l.text for l in top)
        k=key(joined)
        if len(k)<4: continue
        prev=counts.get(k, (0,joined,False))
        counts[k]=(prev[0]+1,joined,prev[2] or tab is not None)
    eligible=[v for v in counts.values() if v[0]>=2 or v[2]]
    if eligible: return max(eligible,key=lambda v:(v[0],len(v[1])))[1]
    for page in pages:
        heights=sorted(l.height for l in page)
        if len(heights)<3: continue
        median=heights[len(heights)//2]
        run=[]
        for l in page:
            if l.height>=median*1.35 and not is_chrome(key(l.text)) and key(l.text) not in {"ingredients","directions","instructions","method"} and marker(l.text) is None: run.append(l.text)
            elif run: break
        if run: return " ".join(run)

def heads_in(page, selected_title):
    # This fixture has known tab-row positions .08 and no metadata, notes,
    # unreliable text, tails or overlapping numbered instructions. This mirrors
    # only the applicable guard/stepHeads paths in RecipeImporter.
    heads={}; current=None
    for l in page:
        k=key(l.text)
        if abs(l.top-.08)<.012 or is_chrome(k): continue
        if len(k)>=4 and key(selected_title) and k in key(selected_title): continue
        n=marker(l.text)
        if n is not None:
            current=n; heads.setdefault(n,[]).append(""); continue
        if current is not None:
            h=heads[current]
            h[-1]=(h[-1]+" "+l.text).strip()
    longest={n:max(copies,key=len) for n,copies in heads.items()}
    return heads,longest

counter_page=[OCRLine("0001 -",.03,height=.02), OCRLine("Ingredients",.08,left=.2,height=.02), OCRLine("Directions",.08,left=.5,height=.02)]
def step_page(n, body):
    return [OCRLine("11:25",.02,height=.02), OCRLine("Ingredients",.08,left=.2,height=.02), OCRLine("Directions",.08,left=.5,height=.02), OCRLine(f"Step {n}",.125,height=.02), OCRLine(TITLE,.15,height=.015), OCRLine(f"STEP {n}",.205,height=.025), OCRLine(body,.245,height=.04)]
short=step_page(3,"Set aside.")
long=step_page(4,"Gently stir ginger and lavender extract into remaining Basic Meringue in mixing bowl using a rubber spatula until evenly incorporated.")
selected=screenshot_title([counter_page,short,long])
assert selected=="0001 -"
short_heads, short_output=heads_in(short,selected)
long_heads, long_output=heads_in(long,selected)
assert short_heads[3]==[TITLE,"Set aside."]
assert short_output[3]==TITLE
assert long_output[4]==long[-1].text

# A2/A1's top16%-only claim is false: this title comes from the fallback
# at top=.30, below .16. Other equal-height lines supply the median.
fallback_page=[OCRLine("11:25",.02,height=.015), OCRLine("Ingredients",.08,left=.2,height=.015), OCRLine("Directions",.08,left=.5,height=.015), OCRLine("0001 -",.30,height=.06), OCRLine("unrelated body",.40,height=.015)]
fallback_title=screenshot_title([fallback_page])
assert fallback_title=="0001 -"

combined="Today News+ Audio Following Search"
assert is_chrome(key(combined))
split=["Today","News+","Audio","Following","Search"]
assert all(not is_chrome(key(s)) for s in split)

print("supplemental narrow Python mirror; NOT Swift or Vision execution")
print("selected title:",selected)
print("short heads:",short_heads,"chosen:",short_output)
print("long heads:",long_heads,"chosen:",long_output)
print("counter below16% fallback:",fallback_title)
print("combined News row filtered:",is_chrome(key(combined)))
print("split News words filtered:",[is_chrome(key(s)) for s in split])
