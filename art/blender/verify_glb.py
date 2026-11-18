"""Check the game-ready skeletons, skin weights, painted geometry and animation timing."""
from pathlib import Path
import struct
import json
import math

ROOT=Path(__file__).resolve().parents[2]
HERO={'Idle','Run','Attack1','Attack2','Attack3','Hook','Spin','Slam','Dodge','Hit','Death',
      'SpearThrust','MaceCrush','BowDraw','StaffCast','Volley','Nova','Rush'}
MONSTER={'Idle','Run','Windup','Attack','Recover','Hit','Death'}


def validate(path):
    data=path.read_bytes()
    assert data[:4]==b'glTF' and struct.unpack_from('<II',data,4)==(2,len(data))
    length=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+length])
    binary=memoryview(data)[28+length:]
    def buffer(index):
        a=doc['accessors'][index]
        v=doc['bufferViews'][a['bufferView']]
        count={'VEC2':2,'VEC3':3,'VEC4':4,'SCALAR':1,'MAT4':16}[a['type']]
        code={5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]
        fmt='<'+count*code
        stride=v.get('byteStride',struct.calcsize(fmt))
        return (struct.unpack_from(fmt,binary,v.get('byteOffset',0)+a.get('byteOffset',0)+i*stride)
                for i in range(a['count']))
    nodes=doc['nodes']; names={n['name'] for n in nodes}
    hero=path.stem=='hero'; tris=0; max_influences=0; max_error=0; min_y=999.; max_y=0.
    assert len(doc['skins'])==1
    joints=doc['skins'][0]['joints']
    for m in doc['meshes']:
        for primitive in m['primitives']:
            a=primitive['attributes']
            assert {'POSITION','NORMAL','COLOR_0','JOINTS_0','WEIGHTS_0','TEXCOORD_0'}<=a.keys()
            tris+=doc['accessors'][primitive['indices']]['count']//3
            position=doc['accessors'][a['POSITION']]
            min_y=min(min_y,position['min'][1]); max_y=max(max_y,position['max'][1])
            for weight,indices in zip(buffer(a['WEIGHTS_0']),buffer(a['JOINTS_0'])):
                assert all(math.isfinite(w) and 0<=w<=1 for w in weight)
                max_error=max(max_error,abs(sum(weight)-1))
                max_influences=max(max_influences,sum(w>0 for w in weight))
                assert all(0<=i<len(joints) for i,w in zip(indices,weight) if w)
                if m['name'] in {'WeaponBase','LoadoutStaff','LoadoutSpear','LoadoutMace'}:
                    assert all(nodes[joints[i]]['name']=='WeaponGrip' for i,w in zip(indices,weight) if w)
                if m['name']=='LoadoutShield':
                    assert all(nodes[joints[i]]['name']=='Hand.L' for i,w in zip(indices,weight) if w)
                if m['name']=='LoadoutBow':
                    assert all(nodes[joints[i]]['name'] in {'WeaponGrip','BowNock'} for i,w in zip(indices,weight) if w)
    assert max_error<.0001 and 0<max_influences<=4
    if path.stem!='pine_wasp':
        assert abs(min_y)<.011,(path.name,min_y)
    else:
        assert 0 < min_y < 1
    if hero:
        assert {'SwordBase','SwordTip','WeaponGrip','WeaponBase'}|{'Grade'+str(i) for i in range(1,7)}<=names
        assert {'LoadoutStaff','LoadoutBow','LoadoutMace','LoadoutSpear','LoadoutShield','BowNock'}<=names
    assert {a['name'] for a in doc['animations']}==(HERO if hero else MONSTER)
    durations={}
    for clip in doc['animations']:
        assert clip['channels'] and all('node' in c['target'] for c in clip['channels'])
        intervals=[doc['accessors'][s['input']] for s in clip['samplers']]
        durations[clip['name']]=max(a['max'][0] for a in intervals)-min(a['min'][0] for a in intervals)
        assert durations[clip['name']]>.07 and any(a['count']>1 for a in intervals)
    if hero:
        for key,frames in [('Attack1',24),('Attack2',28),('Attack3',42),('Hook',35),('Spin',46),('Slam',53),('Dodge',24),
                           ('SpearThrust',30),('MaceCrush',42),('BowDraw',26),('StaffCast',35),('Volley',30),('Nova',46),('Rush',34)]:
            assert abs(durations[key]*60-frames)<.01,(key,durations[key],frames)
    assert doc['images']
    v=doc['bufferViews'][doc['images'][0]['bufferView']]
    start=v.get('byteOffset',0)
    assert bytes(binary[start:start+8])==bytes.fromhex('89504e470d0a1a0a')
    size=struct.unpack_from('>II',binary,start+16)
    expected=2048 if path.stem in {'hero','trap_antler','wheelback'} else 1024
    assert size==(expected,expected)
    print(f'{path.stem}: {tris:,} tris / {len(joints)} joints / {max_influences} weights '
          f'/ max sum error {max_error:.7f} / y [{min_y:.3f}, {max_y:.3f}] / {len(durations)} clips / {size[0]}px')


if __name__=='__main__':
    expected=['hero','acorn_mouse','pine_wasp','moss_boar','husk_shield','drum_shroom','trap_antler','wheelback']
    for name in expected:
        validate(ROOT/'game/assets/models'/(name+'.glb'))
