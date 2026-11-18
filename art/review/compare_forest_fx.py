"""Assemble paired runtime samples captured by record_forest_combat.gd."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageStat

root=Path(__file__).resolve().parents[2]
source=Path(sys.argv[1])
font=ImageFont.truetype(str(root/'game/assets/fonts/NotoSansKR.ttf'),23)
small=ImageFont.truetype(str(root/'game/assets/fonts/NotoSansKR.ttf'),17)
crop=(440,190,952,475)
sheet=Image.new('RGB',(1024,42+3*316),(27,39,49))
draw=ImageDraw.Draw(sheet)
for col,label in enumerate(['기본 효과','섬광 약화']):
    draw.text((col*512+12,4),label,font=font,fill='#eceddb')
for row,(frame,label) in enumerate([(25,'갈퀴 적중'),(207,'고철 회오리와 뿌리 예고'),(285,'압착 강타')]):
    pair=[]
    for col,name in enumerate(['normal','reduced']):
        with Image.open(source/f'{name}_{frame:03d}.png') as full:
            pair.append(full.convert('RGB'))
        y=42+row*316
        sheet.paste(pair[-1].crop(crop),(col*512,y))
        draw.text((col*512+12,y+286),label,font=small,fill='#e4e8d9')
    difference=ImageChops.difference(*pair)
    delta=ImageStat.Stat(difference.crop(crop)).mean
    print(f'{frame:3d} character-area RGB absolute difference mean {sum(delta)/3:.3f}; full changed bounds {difference.getbbox()}')
    assert difference.crop(crop).getbbox(), 'The capture pair did not change hero effects'
sheet.save(root/'art/review/forest_flash_comparison.webp',quality=92)
