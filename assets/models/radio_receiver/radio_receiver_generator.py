#!/usr/bin/env python3
"""Coffee Shift — original tabletop AM/FM radio, PS2+ / Cozy Realism.

Creates a metrically scaled, Godot-friendly GLB using trimesh & Pillow.
Axes: X right, Y up, +Z toward the user; origin at center of base.
All parts are authored here as editable procedural primitives; no external assets.
"""
from pathlib import Path
from math import cos, sin, pi
import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
MAT = {}
PARTS = []
SCENE = trimesh.Scene()

PALETTE = {
    'cream': '#D6CCB3',
    'cream_light': '#E7DCC1',
    'cream_shadow': '#B4AA94',
    'olive': '#576C61',
    'olive_light': '#6D8071',
    'olive_dark': '#34463E',
    'dark': '#24332F',
    'hole': '#111D1C',
    'brass': '#BB955F',
    'brass_light': '#D4B47D',
    'metal': '#A0ADA7',
    'silver': '#C3CECB',
    'black': '#262A2A',
    'rust': '#BF674C',
}

def material(name, color, rough=.74, metal=.0):
    if name not in MAT:
        rgb = tuple(int(color[i:i+2], 16) for i in (1,3,5))
        MAT[name] = trimesh.visual.material.PBRMaterial(
            name=name, baseColorFactor=list(rgb)+[255],
            metallicFactor=metal, roughnessFactor=rough,
            doubleSided=True,
        )
    return MAT[name]

def add(name, mesh, matname, col=None, rough=.75, metal=0.0):
    if isinstance(matname, trimesh.visual.material.PBRMaterial):
        mat = matname
    else:
        mat = material(matname, col or PALETTE[matname], rough, metal)
    if not isinstance(mesh.visual, trimesh.visual.TextureVisuals) or mesh.visual.uv is None:
        mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    else:
        mesh.visual.material = mat
    SCENE.add_geometry(mesh, geom_name=name, node_name=name)
    PARTS.append({'name':name,'triangles':len(mesh.faces)})

def rounded_outline(w, h, r, steps=5):
    r = max(0.0001, min(r, w/2, h/2))
    points=[]
    # counter-clockwise perimeter
    for cx,cy,start in [
        (w/2-r, h/2-r, 0),
        (-w/2+r, h/2-r, pi/2),
        (-w/2+r,-h/2+r, pi),
        (w/2-r,-h/2+r, 3*pi/2),
    ]:
        for j in range(steps+1):
            a=start+(pi/2)*j/steps
            points.append((cx+r*cos(a), cy+r*sin(a)))
    return np.array(points)

def rounded_box(w,h,d,r=0.01,center=(0,0,0),name=None,bevel=0.0):
    # Surface strip rings: small front/back inset to suggest a smooth, molded casing.
    N=6
    edge=max(0,min(bevel,d*.35,w*.12,h*.12))
    layers = [(-d/2,edge),(-d/2+edge,0),(d/2-edge,0),(d/2,edge)] if edge else [(-d/2,0),(d/2,0)]
    loops=[]
    for z,inset in layers:
        flat=rounded_outline(w-2*inset,h-2*inset,max(.001,r-inset),N)
        loops.append(np.c_[flat, np.full(len(flat),z)] + np.array(center))
    L=len(loops[0]);vertices=np.vstack(loops)
    faces=[]
    for j in range(len(loops)-1):
        for k in range(L):
            a=j*L+k;b=j*L+(k+1)%L;c=(j+1)*L+k;d2=(j+1)*L+(k+1)%L
            faces.extend([(a,b,c),(b,d2,c)])
    # Flat cap normals: duplicate rim vertices so front/back planes remain flat
    # and do not inherit bevel's smoothed vertex normals.
    b_ring=len(vertices)
    f_ring=b_ring+L
    vertices=np.vstack([
        vertices, loops[0].copy(), loops[-1].copy(),
        np.array(center)+[0,0,-d/2],np.array(center)+[0,0,d/2],
    ])
    b_center=len(vertices)-2; f_center=len(vertices)-1
    for k in range(L):
        faces.append((b_center,b_ring+(k+1)%L,b_ring+k))
        faces.append((f_center,f_ring+k,f_ring+(k+1)%L))
    return trimesh.Trimesh(vertices=vertices,faces=np.array(faces),process=False)

def box(name, size, center, mat, bevel=0, radius=None,rough=.73,metal=.0):
    if radius is not None:
        shape=rounded_box(size[0],size[1],size[2],radius,center,bevel=bevel)
    else:
        shape=trimesh.creation.box(extents=size)
        shape.apply_translation(center)
    add(name,shape,mat,rough=rough,metal=metal)
    return shape

def cyl(name, radius, length, p1, p2, mat, sections=20,rough=.6,metal=0.0):
    p1=np.array(p1,dtype=float);p2=np.array(p2,dtype=float)
    vec=p2-p1
    geo=trimesh.creation.cylinder(radius=radius,height=float(np.linalg.norm(vec)),sections=sections)
    rot=trimesh.geometry.align_vectors((0,0,1),vec)
    geo.apply_transform(rot)
    geo.apply_translation((p1+p2)/2)
    add(name,geo,mat,rough=rough,metal=metal)

def sphere(name,r,center,mat,subdiv=1):
    s=trimesh.creation.icosphere(subdivisions=subdiv,radius=r)
    s.apply_translation(center)
    add(name,s,mat)

def quad_texture(name, center, wh, z, path, rough=.65, flip_x=False):
    x,y=center;w,h=wh
    verts=np.array([[x-w/2,y-h/2,z],[x+w/2,y-h/2,z],[x+w/2,y+h/2,z],[x-w/2,y+h/2,z]])
    geo=trimesh.Trimesh(vertices=verts,faces=[[0,1,2],[0,2,3]],process=False)
    uv=np.array([[1,0],[0,0],[0,1],[1,1]]) if flip_x else np.array([[0,0],[1,0],[1,1],[0,1]])
    m=trimesh.visual.material.PBRMaterial(
        name='Label_'+name, baseColorTexture=Image.open(path).convert('RGBA'),
        metallicFactor=0.0,roughnessFactor=rough,doubleSided=True,
    )
    geo.visual=trimesh.visual.TextureVisuals(uv=uv,material=m)
    add(name,geo,m)

def font(px,bold=False):
    fs=[
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
    ]
    for f in fs:
        if Path(f).exists():return ImageFont.truetype(f,px)
    return ImageFont.load_default()

def freq_texture():
    W,H=1200,230
    img=Image.new('RGBA',(W,H),(25,41,40,255)); d=ImageDraw.Draw(img)
    # glass panel mild gradient
    for y in range(H):
        t=y/H
        d.line((0,y,W,y), fill=(round(27+4*(1-t)),round(43+6*(1-t)),round(40+5*(1-t)),255))
    d.rounded_rectangle((4,4,W-5,H-5),radius=25,outline=(185,167,120,255),width=5)
    d.text((44,20),'FM',font=font(51,True),fill=(216,181,123,255))
    d.text((173,27),'МГц',font=font(37),fill=(172,192,179,255))
    x0,x1=312,1135
    yline=175
    d.line((x0,yline,x1,yline), fill=(210,209,172,255),width=3)
    for mhz in range(88,109):
        xx=round(x0+(mhz-88)/20*(x1-x0))
        major=mhz%4==0 or mhz==108
        ht=44 if major else 19
        d.line((xx,yline-ht,xx,yline+9),fill=(224,223,198,255) if major else (139,168,154,255),width=4 if major else 2)
        if major:
            bb=d.textbbox((0,0),str(mhz),font=font(34,True))
            tw=bb[2]-bb[0]
            d.text((xx-tw/2,46),str(mhz),font=font(34,True),fill=(218,211,173,255))
    # red/orange tuning needle at about 101.1 MHz
    xx=int(x0+(101.1-88)/20*(x1-x0))
    d.line((xx,60,xx,191),fill=(233,111,75,255),width=9)
    d.ellipse((xx-9,55,xx+9,73),fill=(242,150,103,255))
    return img

def brand_texture():
    W,H=760,130
    img=Image.new('RGBA',(W,H),(77,99,86,255));d=ImageDraw.Draw(img)
    d.rounded_rectangle((2,2,W-3,H-3),radius=15,outline=(175,164,130,255),width=4)
    d.text((37,22),'СЕВЕР • FM',font=font(60,True),fill=(236,223,187,255))
    return img

def back_texture():
    W,H=850,200
    img=Image.new('RGBA',(W,H),(50,67,59,255));d=ImageDraw.Draw(img)
    d.text((37,29),'СЕВЕР — ПРИЁМНИК FM/AM',font=font(43,True),fill=(223,218,194,255))
    d.text((37,103),'ПИТАНИЕ: 220 В / БАТАРЕИ',font=font(30),fill=(197,205,188,255))
    return img

def make():
    OUT.mkdir(parents=True,exist_ok=True)
    freq_texture().save(OUT/'radio_fm_dial.png')
    brand_texture().save(OUT/'radio_brand.png')
    back_texture().save(OUT/'radio_back_label.png')

    # Body — 302 x 174 x 100 mm, with PS2-friendly rounded silhouette.
    box('01_Housing_Ivory',(0.302,0.174,0.100),(0,0.100,0),'cream',radius=.018,bevel=.004)
    box('02_FrontTrim_Brass',(0.278,0.152,0.005),(0,0.100,.051),'brass',radius=.014,bevel=.001,rough=.58,metal=.28)
    box('03_FrontPlate_Olive',(0.274,0.148,0.004),(0,0.100,.0545),'olive',radius=.012,bevel=.0008)
    # Body horizontal seam line
    box('04_TopFace',(0.276,0.006,0.080),(0,.182,-.002),'cream_light',radius=.002)
    # Decorative top separator and upper control tab
    box('05_FrontTopStrip',(0.255,0.0022,0.002),(0,.168,.058),'brass_light',radius=.001)

    # Left speaker section with pseudo-perforations; no alpha, good performance in Godot.
    box('06_Grille_Frame',(0.155,0.086,0.004),(-.057,.084,.0585),'brass',radius=.010,rough=.69,metal=.12)
    box('07_Grille_Back',(0.150,0.081,0.003),(-.057,.084,.0613),'olive_dark',radius=.008)
    # arranged speaker-hole geometry
    cols,rows=12,7
    for row in range(rows):
        yy=.050 + row*.0114
        for col in range(cols):
            xx=-.125+col*.0124
            cyl(f'08_GrilleHole_r{row:02}_c{col:02}',.00325,.00045,
                (xx,yy,.06310),(xx,yy,.06355),'hole',sections=8,rough=.97)

    # Frequency band over speaker, slightly above grille
    box('09_Frequency_Frame',(0.174,0.032,.003),(-.052,.150,.058),'brass',radius=.004,rough=.51,metal=.2)
    quad_texture('10_FM_Dial',(-.052,.150),(.169,.027),.0610,OUT/'radio_fm_dial.png',rough=.30)
    # A small satin reflective lip along glass
    box('11_Dial_Glass_Highlight',(0.158,.0012,.0008),(-.052,.1615,.06145),'silver',radius=.0005,rough=.30,metal=.45)

    # Fictional manufacturer badge below speaker
    box('12_BrandBadge_Base',(0.107,.019,.002),(-.080,.029,.060),'olive_light',radius=.003)
    quad_texture('13_BrandLabel',(-.080,.029),(.103,.015),.0615,OUT/'radio_brand.png')

    # Separate concentric control knobs — axes aligned to front (+Z).
    for name, x, y, rad, tick in [
        ('Volume',.093,.110,.020,3.95),
        ('Tune',.093,.055,.018,2.3),
    ]:
        cyl(f'20_{name}_Collar',rad+.005,.004,(x,y,.057),(x,y,.061),'olive_dark',24)
        cyl(f'21_{name}_ChromeRim',rad+.002,.004,(x,y,.060),(x,y,.064),'brass',24,rough=.48,metal=.45)
        cyl(f'22_{name}_Knob',rad,.010,(x,y,.063),(x,y,.073),'cream_light',28,rough=.67)
        cyl(f'23_{name}_Top',rad*.82,.0015,(x,y,.073),(x,y,.0745),'cream',24,rough=.68)
        xx=x+rad*.62*cos(tick);yy=y+rad*.62*sin(tick)
        sphere(f'24_{name}_Index',.0025,(xx,yy,.075),'rust',1)
        # Dark radial tick marks around the knob collar
        for aidx in range(9):
            a=(pi*.20)+aidx*(pi*1.60/8)
            xx0=x+(rad+.008)*cos(a); yy0=y+(rad+.008)*sin(a)
            cyl(f'25_{name}_Scale_{aidx:02}',.0007,.0005,(xx0,yy0,.0610),(xx0,yy0,.0615),'cream_shadow',6)

    # Raised carry handle: two supports and a leather-colored grip
    # Anchored at either side of the top of the body.
    for side,x in (('L',-.102),('R',.102)):
        box(f'30_HandlePost_{side}',(.014,.033,.017),(x,.201,-.016),'olive_dark',radius=.004,bevel=.001)
        cyl(f'31_HandlePin_{side}',.005,.012,(x,.217,-.026),(x,.217,-.014),'brass',16,rough=.46,metal=.55)
    box('32_Handle_Bar',(.221,.019,.019),(0,.225,-.015),'olive_dark',radius=.008,bevel=.003)
    box('33_Handle_Grip',(.088,.017,.020),(0,.225,-.014),'cream_shadow',radius=.005,bevel=.002)

    # Telescopic antenna mounted toward rear right; slant is intentional.
    cyl('40_AntennaBase',.009,.015,(.119,.185,-.035),(.122,.198,-.038),'black',16,rough=.44)
    cyl('41_Antenna_Bottom',.0043,.093,(.121,.192,-.035),(.143,.282,-.044),'metal',12,rough=.37,metal=.8)
    cyl('42_Antenna_Middle',.0031,.085,(.142,.278,-.044),(.166,.360,-.054),'silver',12,rough=.29,metal=.8)
    cyl('43_Antenna_Top',.0022,.075,(.165,.355,-.054),(.187,.426,-.062),'silver',10,rough=.28,metal=.82)
    sphere('44_Antenna_Tip',.004,(.187,.426,-.062),'brass_light',2)

    # Right side functional switch and twin machine screws
    box('50_OnOffTrack',(.002,.029,.017),(.151,.134,-.001),'olive_dark',radius=.0006)
    box('51_OnOffSlider',(.006,.012,.018),(.154,.140,-.001),'cream_shadow',radius=.002)
    for side,x in (('L',-.124),('R',.124)):
        cyl(f'52_Front_Screw_{side}',.0022,.0008,(x,.034,.058),(x,.034,.0588),'metal',10,rough=.43,metal=.50)

    # Rear panel, vents, label and battery compartment
    box('60_BackPanel',(0.257,.120,.002),(0,.103,-.052),'olive',radius=.010)
    for i in range(8):
        box(f'61_BackVent_{i:02}',(.115,.0024,.00055),(-.048,.080+i*.007,-.0535),'olive_dark',radius=.001)
    box('62_BackBatteryCover',(.078,.057,.002),(.073,.085,-.054),'cream_shadow',radius=.004)
    box('63_BackLabelPanel',(.176,.029,.0015),(-.016,.157,-.0535),'olive_dark',radius=.003)
    # Rear-facing label with flipped U to read correctly when viewed from the back.
    quad_texture('64_BackLabel',(-.016,.157),(.173,.026),-.0546,OUT/'radio_back_label.png',flip_x=True)
    # Feet contact the counter; origin is base of feet, y = 0.
    for xx in (-.111,.111):
        for zz in (-.034,.034):
            box(f'70_RubberFoot_x{xx:+.3f}_z{zz:+.3f}',(.032,.013,.022),(xx,.0065,zz),'black',radius=.004,bevel=.002)

    # Batch static low-poly details by material to reduce mesh nodes/draw calls.
    # The six rotary-knob pieces remain separately addressable in Godot.
    grouped = {}
    optimized = trimesh.Scene()
    import re
    for part_name, g in SCENE.geometry.items():
        mat = g.visual.material
        is_label = getattr(mat, 'baseColorTexture', None) is not None
        independent = bool(re.match(r'2[234]_(Volume|Tune)_',part_name))
        if is_label or independent:
            optimized.add_geometry(g.copy(), geom_name=part_name, node_name=part_name)
        else:
            grouped.setdefault(mat.name, []).append(g)
    for mat_name, solids in grouped.items():
        geom = trimesh.util.concatenate(solids)
        geom.visual = trimesh.visual.TextureVisuals(material=solids[0].visual.material)
        optimized.add_geometry(geom,geom_name='Static_'+mat_name,node_name='Static_'+mat_name)
    out=OUT/'coffee_shift_radio_receiver.glb'
    data=optimized.export(file_type='glb')
    out.write_bytes(data)
    import json
    bounds=optimized.bounds
    details={
      'asset':'Coffee Shift — table radio СЕВЕР 2012',
      'license':'Original work generated for this task; no third-party 3D or texture assets.',
      'target':'Godot 4.3+, PS2+ / Cozy Realism',
      'unit':'meters',
      'axis':'Y up; front +Z; origin at base',
      'body_dimensions_m':{'width':.302,'height':.174,'depth':.100},
      'total_dimensions_with_antenna_m':{'width':round(float(bounds[1][0]-bounds[0][0]),4),'height':round(float(bounds[1][1]-bounds[0][1]),4),'depth':round(float(bounds[1][2]-bounds[0][2]),4)},
      'original_parts':len(PARTS),
      'batched_parts':len(optimized.geometry),
      'triangles':sum(p['triangles'] for p in PARTS),
      'files':{'glb':out.name,'source':'radio_receiver_generator.py',
          'textures':['radio_fm_dial.png','radio_brand.png','radio_back_label.png']},
    }
    (OUT/'radio_model_manifest.json').write_text(json.dumps(details,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Exported',out,'bytes',out.stat().st_size,'batched_meshes',len(optimized.geometry),'triangles',details['triangles'])
    return details

if __name__=='__main__':make()
