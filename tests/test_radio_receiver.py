from pathlib import Path
import json
import numpy as np
import trimesh


def run_test(root: Path):
    glb = root / 'coffee_shift_radio_receiver.glb'
    manifest = json.loads((root / 'radio_model_manifest.json').read_text(encoding='utf-8'))
    assert glb.read_bytes()[:4] == b'glTF', 'GLB binary header mismatch'
    scene = trimesh.load(glb, force='scene')
    assert len(scene.geometry) <= 25, f'too many mesh nodes: {len(scene.geometry)}'
    assert any('Volume' in name for name in scene.geometry)
    assert any('Tune' in name for name in scene.geometry)
    assert any('FM_Dial' in name for name in scene.geometry)
    assert sum(len(m.faces) for m in scene.geometry.values()) == manifest['triangles']
    for name, mesh in scene.geometry.items():
        assert np.isfinite(mesh.vertices).all(), f'nonfinite position in {name}'
        assert len(mesh.faces) > 0
    assert np.allclose(scene.bounds[0][1],0,atol=.0001)
    assert abs(scene.bounds[1][1]-.43) < .005
    assert sum(getattr(x.visual.material,'baseColorTexture',None) is not None for x in scene.geometry.values()) == 3
    print('PASS: glb, scene graph, dimensions, geometry, textures, independent knobs')

if __name__ == '__main__':
    run_test(Path(__file__).resolve().parent.parent / 'assets' / 'models' / 'radio_receiver')
