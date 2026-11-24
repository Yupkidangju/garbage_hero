"""Validate the shipped asset contract and build readable review contact sheets."""
import json, hashlib, struct
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
UI=ROOT/'game/assets/ui'
HERE=Path(__file__).resolve().parent
rows=json.loads((ROOT/'game/data/item_catalog.json').read_text(encoding='utf-8'))
manifest=json.loads((HERE/'item_manifest.json').read_text(encoding='utf-8'))
by_id={x['id']:x for x in manifest}
assert len(rows)==len(manifest)==88
records=[]
for row in rows:
    ident=row['id'];icon=UI/'items'/('item_%03d.png'%ident)
    model=ROOT/'game/assets/models/items'/('item_%03d.glb'%ident)
    image=Image.open(icon)
    assert image.mode=='RGBA' and image.size==(384,384),(ident,image.mode,image.size)
    alpha=image.getchannel('A');box=alpha.getbbox();ext=alpha.getextrema()
    assert box and ext==(0,255),(ident,box,ext)
    assert box[0]>0 and box[1]>0 and box[2]<384 and box[3]<384,(ident,'clipped',box)
    raw=model.read_bytes();magic,ver,length=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and ver==2 and length==len(raw)
    length,kind=struct.unpack_from('<II',raw,12)
    doc=json.loads(raw[20:20+length])
    names=[n.get('name','') for n in doc['nodes']]
    assert any(('Item_%03d_'%ident) in n and row['visual']['shape'] in n for n in names),(ident,names)
    assert doc.get('meshes') and not doc.get('skins')
    assert all('COLOR_0' in prim['attributes'] and 'NORMAL' in prim['attributes'] for m in doc['meshes'] for prim in m['primitives'])
    count=sum(doc['accessors'][prim['indices']]['count']//3 for m in doc['meshes'] for prim in m['primitives'])
    assert count==by_id[ident]['triangles'],(ident,count,by_id[ident]['triangles'])
    records.append(dict(id=ident,kind=row['kind'],shape=row['visual']['shape'],triangles=count,
        icon_bounds=box,icon_sha256=hashlib.sha256(icon.read_bytes()).hexdigest(),model_sha256=hashlib.sha256(raw).hexdigest()))
assert len({r['icon_sha256'] for r in records})==88
assert len({r['model_sha256'] for r in records})==88

for size in [64,128]:
    w=size;h=size+22
    sheet=Image.new('RGB',(11*w,8*h),'#202d39');draw=ImageDraw.Draw(sheet)
    for k,row in enumerate(rows):
        icon=Image.open(UI/'items'/('item_%03d.png'%row['id'])).resize((size,size),Image.Resampling.LANCZOS)
        x,y=(k%11)*w,(k//11)*h;sheet.paste(icon,(x,y),icon)
        draw.text((x+3,y+size+2),'%02d %s'%(row['id'],row['kind']),fill='#f3e8ce')
    sheet.save(HERE/('items_%d.png'%size))

names=['portraits/'+x for x in ['hero','shop','traveler','elder']]
names+=['skills/'+x for x in ['hook','spin','slam','volley','nova','rush']]
names+=['regions/'+x for x in ['forest','desert','graveyard','swamp','snow','volcano']]
names+=['workshop_panel','workshop_frame']
sheet=Image.new('RGB',(6*256,3*280),'#182533');draw=ImageDraw.Draw(sheet)
illustrations=[]
for k,name in enumerate(names):
    path=UI/(name+'.png');im=Image.open(path)
    assert min(im.size)>=1024,(name,im.size)
    if name.startswith(('skills/','portraits/')):assert im.width==im.height
    if name=='workshop_frame':
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        assert im.getpixel((im.width//2,im.height//2))[3]==0
    thumb=im.copy();thumb.thumbnail((256,256),Image.Resampling.LANCZOS)
    x,y=(k%6)*256,(k//6)*280
    if thumb.mode=='RGBA':sheet.paste(thumb,(x+(256-thumb.width)//2,y+(256-thumb.height)//2),thumb)
    else:sheet.paste(thumb,(x+(256-thumb.width)//2,y+(256-thumb.height)//2))
    draw.text((x+5,y+258),name,fill='#f3e8ce')
    illustrations.append(dict(name=name,size=im.size,mode=im.mode,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
sheet.save(HERE/'illustrations_review.png')
report=dict(item_count=len(records),illustration_count=len(illustrations),triangles_min=min(r['triangles'] for r in records),
    triangles_max=max(r['triangles'] for r in records),triangles_total=sum(r['triangles'] for r in records),
    items=records,illustrations=illustrations)
(HERE/'asset_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('VALIDATED',len(records),'distinct transparent384px icons and matching GLBs;',len(illustrations),'illustrations')
print('Triangle range',report['triangles_min'],report['triangles_max'],'total',report['triangles_total'])
