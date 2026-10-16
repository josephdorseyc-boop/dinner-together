#!/usr/bin/env python3
"""Original, deterministic vector artwork. No downloads, embedded rasters or fonts."""
from __future__ import annotations
import copy, hashlib, html, json, math, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent
PALETTE = {
    'paper': '#FFF9ED', 'rim': '#D8CBB1', 'shadow': '#D7C7AD',
    'olive': '#4A583B', 'leaf': '#718451', 'sage': '#A6AC78',
    'tomato': '#AC3526', 'apricot': '#E8A568', 'gold': '#D7A45B',
    'bread': '#EBCB88', 'cream': '#F1E2BC', 'brown': '#885238',
    'sear': '#5C392B', 'salmon': '#D97B5A', 'rose': '#B77D64',
    'white': '#FFFCF4', 'plum': '#89635B',
}

def color(v): return PALETTE.get(v, v)

def ellipse(x, y, rx, ry, fill, stroke=None, width=0, detail=False, opacity=1):
    return dict(kind='ellipse', values=[x,y,rx,ry], commands=[],
                fill=color(fill) if fill else None, stroke=color(stroke) if stroke else None,
                strokeWidth=width, detail=detail, opacity=opacity)

def path(d, fill=None, stroke=None, width=0, detail=False, opacity=1):
    tokens=re.findall(r'[MLCQZ]|-?(?:\d+(?:\.\d*)?|\.\d+)',d)
    counts={'M':2,'L':2,'C':6,'Q':4,'Z':0}; commands=[]; i=0
    while i<len(tokens):
        op=tokens[i]; i+=1; n=counts[op]
        commands.append(dict(op=op, values=[float(x) for x in tokens[i:i+n]])); i+=n
    return dict(kind='path',values=[],commands=commands,
                fill=color(fill) if fill else None,stroke=color(stroke) if stroke else None,
                strokeWidth=width,detail=detail,opacity=opacity)

def poly(points, fill, stroke=None, width=0, detail=False):
    return path('M '+' L '.join(f'{x:g} {y:g}' for x,y in points)+' Z',fill,stroke,width,detail)

def transform(layers, scale=1, x=0, y=0):
    layers=copy.deepcopy(layers)
    for l in layers:
        if l['kind']=='ellipse':
            a,b,rx,ry=l['values']; l['values']=[a*scale+x,b*scale+y,rx*scale,ry*scale]
        else:
            for c in l['commands']:
                c['values']=[v*scale+(x if j%2==0 else y) for j,v in enumerate(c['values'])]
        l['strokeWidth']*=scale
    return layers

def leaf(x,y,w=32,h=17,angle=0,fill='leaf',detail=False):
    l=path(f'M {x-w/2} {y} Q {x} {y-h} {x+w/2} {y} Q {x} {y+h} {x-w/2} {y} Z',fill,detail=detail)
    a=math.radians(angle)
    for c in l['commands']:
        p=c['values']
        for i in range(0,len(p),2):
            dx,dy=p[i]-x,p[i+1]-y
            p[i]=x+dx*math.cos(a)-dy*math.sin(a);p[i+1]=y+dx*math.sin(a)+dy*math.cos(a)
    return l

def herbs():
    return [path('M 142 174 Q 158 150 174 128',stroke='olive',width=3,detail=True)] + [
        leaf(155,153,18,8,-35,detail=True),leaf(165,142,19,8,40,detail=True),leaf(173,131,17,8,-20,detail=True)]

def bowl(fill):
    return [path('M 45 127 Q 54 201 128 204 Q 204 200 211 127 Z','paper','rim',3),
            ellipse(128,126,84,49,'white','rim',3),ellipse(128,124,72,37,fill)]

def lemon(x,y,r=21):
    out=[ellipse(x,y,r,r,'gold'),ellipse(x,y,r-3,r-3,'bread')]
    for a in range(0,360,60):
        b=math.radians(a)
        out.append(path(f'M {x} {y} L {x+(r-6)*math.cos(b)} {y+(r-6)*math.sin(b)}',stroke='white',width=2,detail=True))
    return out

def food(name):
    a=[]
    if name=='Steak':
        a=[path('M 49 104 C 48 74 74 54 112 58 C 131 62 139 47 163 62 C 197 79 211 118 195 155 C 181 190 147 202 108 188 C 77 184 46 154 49 104 Z','brown','sear',5),
           path('M 62 97 C 92 68 122 73 147 70 C 171 78 190 107 184 140 C 170 113 106 156 68 127 Z','gold',opacity=.18)]
        for x,y in [(76,101),(97,91),(123,89),(149,94),(169,111)]:
            a.append(path(f'M {x} {y} L {x+30} {y+58}',stroke='sear',width=7,detail=x not in [97,149]))
        a+=herbs()
    elif name=='Mash':
        a=[path('M 53 162 C 38 145 54 131 69 124 C 50 105 72 91 95 94 C 94 70 127 69 143 86 C 164 68 191 88 180 109 C 209 112 217 136 198 151 C 209 171 174 187 143 181 C 110 197 67 188 53 162 Z','cream','gold',3),
           path('M 74 122 C 95 109 114 113 133 117 M 95 147 C 116 135 143 137 167 145 M 133 92 Q 161 112 151 127',stroke='bread',width=6,detail=True),
           poly([(119,111),(148,110),(151,133),(121,136)],'bread','gold',2)]
        a += [leaf(102,165,18,8,-15,detail=True),leaf(151,154,19,8,30,detail=True)]
    elif name=='Green beans':
        for x,y,dx,dy in [(58,91,117,43),(66,132,122,9),(77,167,101,-63),(90,68,97,91),(60,159,140,-44),(96,180,85,-86),(50,113,136,43)]:
            a += [path(f'M {x} {y} Q {x+dx*.52} {y+dy*.55-15} {x+dx} {y+dy}',stroke='olive',width=12),
                  path(f'M {x+3} {y-2} Q {x+dx*.52} {y+dy*.55-18} {x+dx-5} {y+dy-2}',stroke='leaf',width=4,detail=True)]
        a += [ellipse(108,104,7,5,'cream',detail=True),ellipse(156,159,7,5,'cream',detail=True)]
    elif name=='Pasta':
        a=[ellipse(128,140,86,56,'bread')]
        for i in range(7):
            x=55+i*14;y=98+(i%3)*11
            a.append(path(f'M {x} {y} C {x+70} {y-27} {x+117} {y+26} {x+17} {y+66} C {x-3} {y+66} {x+17} {y+18} {x+85} {y+33}',stroke='gold',width=8))
        for x,y in [(81,120),(156,111),(141,165)]:
            a+=[path(f'M {x-13} {y} Q {x} {y-24} {x+17} {y} Z','brown'),path(f'M {x-3} {y} L {x-3} {y+12} L {x+4} {y+12} L {x+4} {y} Z','cream')]
        a += [leaf(100,80,31,17,-20),leaf(130,83,23,14,40)]
    elif name in ['Salad','Lemony salad']:
        a=bowl('sage')
        for x,y,w,h,ang,c in [(69,119,43,27,30,'olive'),(107,99,45,28,-30,'leaf'),(147,110,45,27,35,'olive'),(181,119,42,28,-30,'leaf'),(91,146,43,27,-30,'leaf'),(144,144,48,29,18,'olive')]:a.append(leaf(x,y,w,h,ang,c))
        for x,y in [(82,107),(157,139),(129,116)]:a += [ellipse(x,y,12,10,'tomato'),ellipse(x-2,y-2,4,2,'apricot',detail=True)]
        if name=='Lemony salad':a+=lemon(180,153,21)
    elif name=='Salmon':
        a=[path('M 59 91 Q 126 54 193 81 L 203 153 Q 140 189 66 160 Z','salmon','brown',4),
           path('M 66 153 Q 138 174 201 146 L 203 153 Q 140 189 66 160 Z','sear')]
        for y in [94,116,138]:a.append(path(f'M 70 {y} Q 127 {y-12} 190 {y-20}',stroke='apricot',width=5))
        a+=lemon(173,176,20)+herbs()
    elif name in ['Rice','Couscous']:
        a=bowl('cream' if name=='Rice' else 'bread')
        for j in range(5):
            for i in range(9):
                x=72+i*13+(j%2)*5;y=102+j*11
                if ((x-128)/63)**2+((y-125)/29)**2<1:
                    if name=='Rice':a.append(ellipse(x,y,5,2.3,'white',detail=not(j==2 and i in [1,3,5,7])))
                    else:a.append(ellipse(x,y,3.5,3,'gold',detail=True))
        if name=='Couscous':
            for x,y in [(82,112),(125,101),(167,118),(132,144)]:a.append(poly([(x,y),(x+7,y),(x+7,y+7),(x,y+7)],'tomato' if x%2==0 else 'olive'))
        a += [leaf(138,91,27,12,-15),leaf(162,92,22,10,30)]
    elif name=='Broccoli':
        for x,y in [(89,112),(157,136),(154,83)]:
            a += [path(f'M {x-8} {y+8} L {x-11} {y+53} L {x+10} {y+57} L {x+9} {y+9} Z','sage')]
            for dx,dy,r in [(-22,2,24),(0,-15,28),(24,0,25)]:a.append(ellipse(x+dx,y+dy,r,r,'olive'))
            for dx,dy in [(-17,-5),(7,-25),(29,-5)]:a.append(ellipse(x+dx,y+dy,12,10,'leaf',detail=True))
    elif name=='Lemon chicken':
        a=[path('M 67 75 C 102 51 157 56 186 90 C 216 125 176 167 137 189 C 101 210 69 171 56 136 C 46 113 48 91 67 75 Z','gold','brown',4),
           path('M 69 92 C 103 66 147 75 171 98 C 151 93 98 136 75 156 C 60 130 56 109 69 92 Z','bread',opacity=.5)]
        for x,y in [(92,111),(126,135),(160,154)]:a.append(path(f'M {x-21} {y+7} L {x+20} {y-13}',stroke='brown',width=5,detail=True))
        a+=lemon(181,83,25)+herbs()
    elif name=='Zucchini':
        for x,y,rx,ry in [(90,88,39,28),(156,124,44,30),(104,167,43,30)]:
            a += [ellipse(x,y,rx,ry,'olive'),ellipse(x,y,rx-6,ry-6,'cream')]
            for dx in [-12,0,12]:a.append(ellipse(x+dx,y,3,6,'sage',detail=True))
    elif name=='Turkey tacos':
        for y in [98,156]:
            a += [path(f'M 44 {y+19} Q 69 {y-55} 183 {y-12} Q 215 {y+2} 211 {y+27} Q 143 {y+51} 44 {y+19} Z','gold','brown',3),
                  path(f'M 55 {y+12} Q 119 {y-31} 196 {y+8} Q 143 {y+36} 55 {y+12} Z','bread'),
                  path(f'M 69 {y+6} Q 120 {y-14} 186 {y+5}',stroke='olive',width=16)]
            for x,dy in [(88,1),(116,-5),(142,-1),(169,5)]:
                a += [ellipse(x,y+dy,9,7,'brown'),ellipse(x+5,y+dy+10,6,5,'tomato')]
    elif name=='Black beans':
        a=bowl('brown')
        for j in range(3):
            for i in range(5):
                x=75+i*24+(j%2)*5;y=107+j*18
                a.append(path(f'M {x-10} {y-4} C {x-2} {y-15} {x+14} {y-10} {x+11} {y+1} Q {x+7} {y+12} {x-1} {y+8} Q {x+3} {y} {x-10} {y-4} Z','sear'))
        a += [leaf(146,95,29,12,-25),leaf(174,102,25,12,25)]
    elif name in ['Crunchy slaw','Cucumber slaw']:
        a=bowl('cream')
        if name=='Crunchy slaw':
            for i in range(9):
                x=65+i*14;y=105+(i%3)*11
                a.append(path(f'M {x} {y} Q {x+25} {y+35} {x+56} {y-4}',stroke=['sage','apricot','plum'][i%3],width=7))
        else:
            for x,y in [(77,115),(114,98),(150,117),(181,115),(115,144),(162,148)]:a += [ellipse(x,y,20,15,'olive'),ellipse(x,y,15,11,'cream'),ellipse(x,y,4,3,'sage',detail=True)]
            a += [path('M 66 130 Q 126 93 182 141',stroke='white',width=5,detail=True)]
    elif name=='Roasted tofu':
        for x,y in [(75,98),(131,86),(102,146),(158,142)]:
            a += [poly([(x-25,y-16),(x+12,y-25),(x+31,y-9),(x-8,y+3)],'bread','gold',2),
                  poly([(x-25,y-16),(x-8,y+3),(x-8,y+38),(x-25,y+19)],'gold'),
                  poly([(x-8,y+3),(x+31,y-9),(x+31,y+23),(x-8,y+38)],'apricot','brown',2)]
            a.append(path(f'M {x-12} {y-6} L {x+13} {y-13}',stroke='brown',width=4,detail=True))
        a+=herbs()
    elif name=='Chickpea curry':
        a=bowl('tomato')
        for x,y in [(75,119),(101,100),(132,102),(161,116),(184,130),(143,143),(107,141)]:
            a += [ellipse(x,y,13,11,'gold'),path(f'M {x-5} {y} Q {x+1} {y-5} {x+6} {y+2}',stroke='bread',width=3,detail=True)]
        a += [leaf(99,84,26,12,-20),leaf(123,84,24,12,25)]
    elif name=='Cucumber yogurt':
        a=bowl('white')
        a+=[path('M 84 119 C 145 89 190 138 126 150 Q 92 151 106 125',stroke='cream',width=5,detail=True)]
        for x,y in [(91,108),(161,132),(116,143)]:a += [poly([(x,y),(x+13,y-3),(x+17,y+9),(x+4,y+12)],'sage'),poly([(x+3,y+2),(x+11,y),(x+13,y+7),(x+5,y+9)],'cream',detail=True)]
        a += [leaf(149,93,29,17,-25),leaf(172,100,26,16,35)]
    elif name=='Skillet gnocchi':
        for x,y,rx,ry in [(68,106,24,17),(115,82,27,18),(170,101,27,18),(101,132,27,18),(161,147,28,19),(80,174,25,17),(133,182,24,17)]:
            a += [ellipse(x,y,rx,ry,'gold'),ellipse(x-2,y-3,rx-4,ry-4,'bread')]
            for dx in [-7,0,7]:a.append(path(f'M {x+dx-3} {y-8} Q {x+dx+6} {y} {x+dx} {y+9}',stroke='gold',width=2,detail=True))
        a += [leaf(183,165,35,17,70,'olive'),leaf(57,151,32,17,-70,'leaf')]
    elif name=='Pork tenderloin':
        for x,y in [(80,87),(108,115),(136,143),(164,171)]:
            a += [ellipse(x,y,38,29,'brown','sear',3),ellipse(x,y-2,31,22,'rose'),ellipse(x-4,y-5,21,13,'apricot',detail=True,opacity=.35)]
        a+=herbs()
    elif name=='Turkey':
        a=[ellipse(127,120,63,79,'brown','sear',4),
           path('M 82 97 C 95 64 139 49 163 89 C 158 111 119 148 89 151 Z','gold',opacity=.55),
           path('M 73 125 Q 45 111 41 153 Q 44 187 77 178 L 95 151 Z','brown','sear',4),
           path('M 180 125 Q 209 111 213 153 Q 212 187 179 178 L 161 151 Z','brown','sear',4),
           path('M 49 170 L 37 185',stroke='cream',width=10),path('M 206 170 L 218 185',stroke='cream',width=10)]
        a += [ellipse(34,188,7,5,'cream'),ellipse(222,188,7,5,'cream')]+herbs()
    elif name=='Stuffing':
        a=bowl('brown')
        for j in range(3):
            for i in range(5):
                x=70+i*26+(j%2)*6;y=100+j*17
                a.append(poly([(x,y),(x+17,y-3),(x+20,y+10),(x+3,y+13)],['bread','gold','apricot'][(i+j)%3],'brown',1))
        a += [leaf(94,94,22,11,-25),leaf(145,134,26,12,35)]
    elif name=='Gravy':
        a=[path('M 62 102 Q 96 80 163 95 L 207 79 Q 189 112 176 135 Q 174 177 138 182 Q 80 187 63 161 Z','paper','rim',4),
           path('M 68 99 Q 117 83 168 96 L 194 89 Q 172 117 129 128 Q 93 127 68 99 Z','brown'),
           path('M 62 118 C 18 85 12 164 63 152',stroke='rim',width=13),
           path('M 62 118 C 26 98 25 152 63 143',stroke='paper',width=7),
           path('M 85 144 Q 94 171 129 173',stroke='white',width=5,detail=True)]
    elif name=='Rolls':
        for x,y in [(91,101),(166,115),(124,168)]:
            a += [ellipse(x,y,45,37,'gold','brown',3),ellipse(x-4,y-7,36,26,'bread'),
                  path(f'M {x-14} {y-16} Q {x} {y-25} {x+17} {y-10}',stroke='cream',width=5,detail=True)]
    else:raise ValueError(name)
    return a

def plate_base():
    return [ellipse(128,133,117,117,'shadow',opacity=.3),
            ellipse(128,126,117,117,'paper','rim',3),
            ellipse(128,126,99,99,None,'rim',2),
            ellipse(128,126,94,94,'white')]

def drawing(key,label,layers):
    return dict(id=key,label=label,viewBox=[0,0,256,256],layers=layers)

def svg(d,thumbnail=False):
    lines=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img">',f'<title>{html.escape(d["label"])}</title>']
    def n(x):return f'{x:.3f}'.rstrip('0').rstrip('.')
    for l in d['layers']:
        if thumbnail and l['detail']:continue
        style=f'fill="{l["fill"] or "none"}" stroke="{l["stroke"] or "none"}" stroke-width="{n(l["strokeWidth"])}" opacity="{n(l["opacity"])}" stroke-linecap="round" stroke-linejoin="round"'
        if l['kind']=='ellipse':
            x,y,rx,ry=l['values'];lines.append(f'<ellipse cx="{n(x)}" cy="{n(y)}" rx="{n(rx)}" ry="{n(ry)}" {style}/>')
        else:
            p=' '.join(c['op']+(' '+' '.join(n(v) for v in c['values']) if c['values'] else '') for c in l['commands'])
            lines.append(f'<path d="{p}" {style}/>')
    return '\n'.join(lines+['</svg>',''])

def catalog():
    s=(ROOT/'DinnerCatalog.baseline.swift').read_text();menus=[]
    for chunk in s.split('DinnerMenu(')[1:]:
        m=re.search(r'id: "([^"]+)", title: "([^"]+)"',chunk)
        if m:menus.append(dict(id=m[1],title=m[2],dishes=list(dict.fromkeys(re.findall(r'step\("[^"]+", "([^"]+)"',chunk)))))
    assert len(menus)==10
    return menus

def build():
    menus=catalog();dishes=list(dict.fromkeys(d for m in menus for d in m['dishes']))
    drawings=[];assets=[]
    for name in dishes:
        slug=re.sub(r'[^a-z0-9]+','-',name.lower()).strip('-')
        d=drawing('dish:'+name,name,plate_base()+food(name));drawings.append(d)
        assets.append(dict(id=d['id'],label=name,kind='dish',svg=f'dishes/{slug}.svg',thumbnailSVG=f'thumbnails/dishes/{slug}.svg'))
    for menu in menus:
        if len(menu['dishes'])==6:
            spots=[(.71,5,23),(.30,151,41),(.32,151,100),(.25,82,169),(.29,17,166),(.28,162,165)]
        elif len(menu['dishes'])==2:spots=[(.81,-1,30),(.46,119,29)]
        else:spots=[(.77,-1,31),(.44,126,25),(.43,118,121)]
        layers=plate_base()
        for dish,(scale,x,y) in zip(menu['dishes'],spots):layers+=transform(food(dish),scale,x,y)
        d=drawing('menu:'+menu['id'],menu['title'],layers);drawings.append(d)
        assets.append(dict(id=d['id'],label=menu['title'],kind='menu',svg=f'plates/{menu["id"]}.svg',thumbnailSVG=f'thumbnails/plates/{menu["id"]}.svg',dishes=menu['dishes']))
    for d,a in zip(drawings,assets):
        for thumb,k in [(False,'svg'),(True,'thumbnailSVG')]:
            p=OUT/a[k];p.parent.mkdir(parents=True,exist_ok=True);p.write_text(svg(d,thumb))
    payload=dict(schemaVersion=1,baseline='cd98223dbb79cd31fff1e1653be638cd7068f9e3',drawings=drawings)
    (OUT/'A2CatalogArtwork.json').write_text(json.dumps(payload,separators=(',',':'))+'\n')
    manifest=dict(schemaVersion=1,baseline=payload['baseline'],palette=PALETTE,menus=menus,assets=assets,
                  thumbnailCutoffPoints=64,decorative=True,source='Original vector artwork authored for Dinner, Together. No third-party assets or generated food photos.')
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'menus':len(menus),'dishes':len(dishes),'drawings':len(drawings),'svgFiles':len(assets)*2,'dataBytes':(OUT/'A2CatalogArtwork.json').stat().st_size}))

if __name__=='__main__':build()
