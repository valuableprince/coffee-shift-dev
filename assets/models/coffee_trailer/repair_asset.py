"""Reproduce the localized corrections to the original PR #74 shell.

Usage: python repair_asset.py --source /path/to/original/coffee_trailer_shell.glb
Default: validate/repair the adjacent GLB. Materials, longitudinal roof profile,
chassis, hatch and door are retained. No replacement trailer is generated.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path)
args = parser.parse_args()
output = Path(__file__).with_name('coffee_trailer_shell.glb')
data = (args.source or output).read_bytes()
length = struct.unpack_from('<I', data, 12)[0]
gltf = json.loads(data[20:20+length])
if gltf['asset'].get('extras', {}).get('integration_repair') == 1:
    print('Already repaired')
    raise SystemExit(0)
binary = bytearray(data[28+length:])
source_sha256 = hashlib.sha256(data).hexdigest()
assert source_sha256 == '9795c187eb585d5fc8c0a2e223ca750c10892c9b06384abedad610a41218e778', 'Expected the original PR #74 shell'

def read(index):
    a = gltf['accessors'][index]
    view = gltf['bufferViews'][a['bufferView']]
    components = {'VEC3':3,'SCALAR':1}[a['type']]
    fmt = {5126:'f',5123:'H',5125:'I'}[a['componentType']]
    stride = view.get('byteStride',struct.calcsize('<'+fmt*components))
    start = view.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*components,binary,start+i*stride) for i in range(a['count'])]

def replace_positions(primitive, convert):
    a = gltf['accessors'][primitive['attributes']['POSITION']]
    view = gltf['bufferViews'][a['bufferView']]
    start = view.get('byteOffset',0)+a.get('byteOffset',0)
    stride = view.get('byteStride',12)
    points = [convert(p) for p in read(primitive['attributes']['POSITION'])]
    for i,p in enumerate(points):struct.pack_into('<fff',binary,start+i*stride,*p)
    a['min']=[min(p[i] for p in points) for i in range(3)]
    a['max']=[max(p[i] for p in points) for i in range(3)]

# Set the visible floor at the approved .400 m, keep the support below it,
# extend the rubber finish 52 mm to meet the rear threshold without a slit.
for mesh in gltf['meshes']:
    for primitive in mesh['primitives']:
        if mesh['name']=='Rubber_Floor':
            replace_positions(primitive, lambda p:(p[0],p[1]-.0495,p[2]* (2.667/2.615)))
        elif mesh['name']=='Aluminium_Dark':
            replace_positions(primitive,lambda p:(p[0],p[1]-.06,p[2]) if p[1]<.414 and abs(p[2])<2.711 else p)
        elif mesh['name']=='Metal_Trim':
            replace_positions(primitive,lambda p:(p[0],p[1]-.047,p[2]) if .416<p[1]<.448 and p[2]>2.66 and abs(p[0])<.491 else p)

# Subtract the actual door opening from rear gable/header triangles.
# Sutherland-Hodgman partition retains the original vertices and face normals;
# only intersected triangles receive interpolated cut vertices at the jambs.
def clip(poly, axis, edge, greater):
    result=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da=(a[axis]-edge)*(1 if greater else -1)
        db=(b[axis]-edge)*(1 if greater else -1)
        inside_a=da>=-1e-8;inside_b=db>=-1e-8
        if inside_a:result.append(a)
        if inside_a != inside_b:
            t=da/(da-db)
            result.append(tuple(a[i]+(b[i]-a[i])*t for i in range(6)))
    return result

def area2(a,b,c):
    u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
    cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
    return sum(x*x for x in cross)

def append_accessor(points, components, kind, target):
    binary.extend(b'\0'*(-len(binary)%4))
    start=len(binary)
    fmt='f' if kind==5126 else 'I'
    flat=[v for p in points for v in p]
    binary.extend(struct.pack('<'+fmt*len(flat),*flat))
    view=len(gltf['bufferViews'])
    gltf['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(binary)-start,'target':target})
    a={'bufferView':view,'componentType':kind,'count':len(points),'type':'VEC3' if components==3 else 'SCALAR'}
    if kind==5126:
        a['min']=[min(p[i] for p in points) for i in range(components)]
        a['max']=[max(p[i] for p in points) for i in range(components)]
    index=len(gltf['accessors']);gltf['accessors'].append(a)
    return index

changes={}
for mesh in gltf['meshes']:
    for primitive in mesh['primitives']:
        positions=read(primitive['attributes']['POSITION']);normals=read(primitive['attributes']['NORMAL'])
        indices=[v[0] for v in read(primitive['indices'])]
        result=[];modified=False;affected=0
        for i in range(0,len(indices),3):
            tri=[positions[j]+normals[j] for j in indices[i:i+3]]
            if min(p[2] for p in tri)>2.68 and min(p[1] for p in tri)>2.149 and min(p[1] for p in tri)<2.3:
                left=clip(tri,0,-.49,False)
                rest=clip(tri,0,-.49,True)
                right=clip(rest,0,.49,True)
                center=clip(rest,0,.49,False)
                top=clip(center,1,2.3,True)
                pieces=[left,right,top]
                affected+=1;modified=True
            else:pieces=[tri]
            for poly in pieces:
                for j in range(1,len(poly)-1):
                    candidate=[poly[0],poly[j],poly[j+1]]
                    if area2(*candidate)>1e-14:result.extend(candidate)
        if modified:
            primitive['attributes']['POSITION']=append_accessor([p[:3] for p in result],3,5126,34962)
            primitive['attributes']['NORMAL']=append_accessor([p[3:] for p in result],3,5126,34962)
            primitive['indices']=append_accessor([(i,) for i in range(len(result))],1,5125,34963)
            changes[mesh['name']]={'source_triangles':len(indices)//3,'result_triangles':len(result)//3,'examined_rear_triangles':affected}
gltf['buffers'][0]['byteLength']=len(binary)
gltf['asset'].setdefault('extras',{}).update({'integration_repair':1,'source_sha256':source_sha256})
encoded=json.dumps(gltf,separators=(',',':'),ensure_ascii=False).encode()
encoded+=b' '*(-len(encoded)%4)
output.write_bytes(struct.pack('<III',0x46546C67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary)
print(json.dumps({'source_sha256':source_sha256,'rear_aperture_changes':changes},indent=2))
