"""Valida paridad de idiomas, marcadores, versión y exclusión de memoria."""
from pathlib import Path
import os
import re
import subprocess
import xml.etree.ElementTree as ET

base = None
for ruta in sorted(Path('recursos/idiomas').glob('*.xml')):
    raiz = ET.parse(ruta).getroot()
    assert raiz.tag == 'idioma' and raiz.attrib['codigo'] == ruta.stem
    textos = {n.attrib['clave']: n.text or '' for n in raiz}
    assert len(textos) == len(raiz), f'Claves duplicadas: {ruta}'
    assert all(texto.strip() for texto in textos.values()), f'Textos vacíos: {ruta}'
    if base is None:
        base = set(textos)
    assert set(textos) == base, f'Claves diferentes: {ruta}'
    for clave, valor in textos.items():
        assert set(re.findall(r'\{\w+\}', clave)) == set(re.findall(r'\{\w+\}', valor)), f'Marcadores distintos: {ruta}: {clave}'

version = re.search(r'^version: ([^+\n]+)', Path('pubspec.yaml').read_text(), re.M)[1]
servicio = Path('lib/actualizaciones/servicio_actualizaciones.dart').read_text()
assert f"versionAplicacion = '{version}'" in servicio, 'Versiones desalineadas'
etiqueta = os.environ.get('GITHUB_REF', '')
if etiqueta.startswith('refs/tags/'):
    assert etiqueta == f'refs/tags/v{version}', 'La etiqueta no coincide con pubspec.yaml'
    assert f'## [{version}]' in Path('CAMBIOS.md').read_text(), 'Falta la versión en CAMBIOS.md'
assert '/memoria/' in Path('.gitignore').read_text()
rastreados = subprocess.check_output(['git', 'ls-files', '--', 'memoria'], text=True)
assert not rastreados.strip(), 'memoria/ contiene archivos versionados'
print(f'Versión {version}; cinco catálogos compatibles con {len(base)} textos; memoria excluida.')
