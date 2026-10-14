#!/usr/bin/env python3
"""Asset checks and Inkscape previews; this does not execute SwiftUI or app tests."""
import concurrent.futures, hashlib, json, math, re, subprocess, xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from build_artwork import catalog, svg

ROOT=Path(__file__).resolve().parent; PACK=ROOT.parent; PREVIEW=PACK/'previews'

def render(job):
    asset,size=job; source=PACK/asset['thumbnailSVG' if size==44 else 'svg']
    out=PREVIEW/str(size)/(asset['id'].replace(':','-').replace(' ','-').lower()+'.png')
    out.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['inkscape',str(source),'--export-type=png',f'--export-filename={out}',f'--export-width={size}',f'--export-height={size}'],check=True,capture_output=True)
    im=Image.open(out).convert('RGBA');assert im.size==(size,size)
    alpha=im.getchannel('A');assert alpha.getextrema()==(0,255)
    bounds=alpha.getbbox();assert bounds and bounds[0]>0 and bounds[1]>=0 and bounds[2]<size and bounds[3]<=size
    return out

def contact(assets,title,file):
    cols=5;w=1500;cellw=w//cols;cellh=335;top=120;rows=math.ceil(len(assets)/cols)
    im=Image.new('RGB',(w,top+rows*cellh+30),'#F7F2E7');p=ImageDraw.Draw(im)
    font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    f=ImageFont.truetype(font,18);small=ImageFont.truetype(font,14);head=ImageFont.truetype(font,30)
    p.text((30,25),title,fill='#2C2A24',font=head)
    p.text((30,75),'Original vector artwork · 220 px hero and 44 px thumbnail · render check, not app evidence',fill='#4A583B',font=f)
    for i,a in enumerate(assets):
        x=(i%cols)*cellw;y=top+(i//cols)*cellh
        key=a['id'].replace(':','-').replace(' ','-').lower()
        big=Image.open(PREVIEW/'220'/(key+'.png')).convert('RGBA')
        tiny=Image.open(PREVIEW/'44'/(key+'.png')).convert('RGBA')
        im.paste(big,(x+40,y),big)
        im.paste(tiny,(x+30,y+235),tiny)
        # The identical 44-px art on a dark card checks its own transparent edges.
        p.rounded_rectangle((x+82,y+229,x+138,y+285),radius=12,fill='#302B25')
        im.paste(tiny,(x+88,y+235),tiny)
        label=a['label']
        p.text((x+16,y+291),label,fill='#2C2A24',font=f if len(label)<27 else small)
    im.save(PREVIEW/file)

def main():
    m=json.load(open(PACK/'manifest.json'));data=json.load(open(PACK/'A2CatalogArtwork.json'))
    assert m['menus']==catalog(); assert data['schemaVersion']==1
    ids=[a['id'] for a in m['assets']];assert len(ids)==len(set(ids))==35
    drawings={d['id']:d for d in data['drawings']};assert set(ids)==set(drawings)
    assert len([a for a in m['assets'] if a['kind']=='menu'])==10
    assert len([a for a in m['assets'] if a['kind']=='dish'])==25
    current=set('dish:'+n for menu in catalog() for n in menu['dishes'])
    assert current=={a['id'] for a in m['assets'] if a['kind']=='dish'}
    command_sizes={'M':2,'L':2,'C':6,'Q':4,'Z':0}
    for a in m['assets']:
        d=drawings[a['id']];assert d['viewBox']==[0,0,256,256]
        for thumb,key in [(False,'svg'),(True,'thumbnailSVG')]:
            p=PACK/a[key];s=p.read_text();ET.fromstring(s)
            assert s==svg(d,thumb),p
            assert not re.search(r'<(?:image|text|foreignObject|script|filter)\b',s)
        for l in d['layers']:
            assert l['kind'] in ['ellipse','path'];assert 0<=l['opacity']<=1
            assert l['strokeWidth']>=0
            for c in l['commands']:
                assert len(c['values'])==command_sizes[c['op']]
                assert all(math.isfinite(v) and -10<v<266 for v in c['values'])
            assert all(math.isfinite(v) for v in l['values'])
            if l['kind']=='ellipse':assert len(l['values'])==4 and min(l['values'][2:])>0
            for color in [l['fill'],l['stroke']]:assert color is None or re.fullmatch('#[0-9A-F]{6}',color)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        images=list(pool.map(render,[(a,size) for a in m['assets'] for size in [44,220]]))
    contact([a for a in m['assets'] if a['kind']=='menu'],'Dinner, Together — classic dinner plates','classic-plates.png')
    contact([a for a in m['assets'] if a['kind']=='dish'],'Dinner, Together — dish illustrations','catalog-dishes.png')
    report={
        'baseline':m['baseline'],'menuCount':10,'dishCount':25,'drawingCount':35,
        'svgCount':70,'pngRenderCount':len(images),'coverage':'complete against inspected catalog',
        'checks':['unique IDs','all menu and dish IDs mapped','SVG / normalized data parity','valid XML','finite bounded geometry','allowed path command arity','no external/raster/font dependencies','transparent padded exports at 44 and 220 pixels'],
        'evidenceTier':'supplemental vector render and data checks; not native app execution',
        'nativeCompilation':'not performed: no Swift/Xcode toolchain here',
        'swiftAdapter':'source review only; A3 must compile and render on supported platforms',
        'assetSHA256':{a['svg']:hashlib.sha256((PACK/a['svg']).read_bytes()).hexdigest() for a in m['assets']}
    }
    (PACK/'VALIDATION.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='assetSHA256'}))

if __name__=='__main__':main()
