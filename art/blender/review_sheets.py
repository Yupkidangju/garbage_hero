"""Render and assemble field-angle turnarounds and four action beats for art review."""
from pathlib import Path
from tempfile import TemporaryDirectory
import os
import subprocess
import sys
from PIL import Image,ImageDraw,ImageFont

folder=Path(__file__).resolve().parent
blender=os.environ.get('BLENDER_EXE',r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe')
for name in sys.argv[1:]:
    source=folder/(name+'.blend')
    if not source.is_file():
        raise FileNotFoundError(source)
    with TemporaryDirectory(dir=folder,prefix='render_') as dest:
        subprocess.run([blender,'-b',str(source),'-t','4','--python-exit-code','1','--python',
            str(folder/'inspect_model.py'),'--',name,dest],check=True,stdout=subprocess.DEVNULL)
        sheet=Image.new('RGB',(1280,3*345),(43,51,58))
        draw=ImageDraw.Draw(sheet)
        try: font=ImageFont.truetype('segoeui.ttf',15)
        except OSError: font=ImageFont.load_default()
        labels=[f'{a}°' for a in range(0,360,45)]+['Ready','Windup','Strike','Recovery']
        for i,label in enumerate(labels):
            x=i%4*320; y=i//4*345
            with Image.open(Path(dest)/(str(i)+'.png')) as tile:
                sheet.paste(tile,(x,y))
            draw.text((x+12,y+322),label,fill=(231,234,220),font=font)
        sheet.save(folder/(name+'_poses.webp'),quality=88)
