"""Impide publicar distribuciones incompletas o archivos con formato incorrecto."""
from pathlib import Path
import argparse
import tarfile
import zipfile

from empaquetar import SALIDA, version


def esperados(numero):
    return {
        'linux': ['glosala-linux.tar.gz', f'glosala_{numero}_amd64.deb',
                  f'glosala-{numero}-1.x86_64.rpm'],
        'windows': ['glosala-windows.zip', f'glosala-{numero}-windows-x64.msi',
                    f'glosala-{numero}-windows-x64-setup.exe'],
        'macos': ['glosala-macos-sin-notarizar.zip', f'glosala-{numero}-macos.dmg',
                  f'glosala-{numero}-macos.pkg'],
        'android': ['glosala-android-pruebas.apk'],
        'ios': ['glosala-ios-sin-firmar.zip'],
        'web': ['glosala-web.zip'],
    }


def verificar(carpeta, plataforma, numero):
    grupos = esperados(numero)
    nombres = sum(grupos.values(), []) if plataforma == 'todos' else grupos[plataforma]
    cabeceras = {'.deb': b'!<arch>\n', '.rpm': bytes.fromhex('edabeedb'),
                 '.msi': bytes.fromhex('d0cf11e0a1b11ae1'), '.exe': b'MZ', '.pkg': b'xar!'}
    for nombre in nombres:
        ruta = carpeta / nombre
        if not ruta.is_file() or ruta.stat().st_size < 1024:
            raise ValueError(f'Falta el paquete o está vacío: {nombre}')
        if ruta.suffix in cabeceras:
            firma = cabeceras[ruta.suffix]
            with ruta.open('rb') as archivo:
                if archivo.read(len(firma)) != firma:
                    raise ValueError(f'Formato incorrecto: {nombre}')
        elif ruta.suffix == '.dmg':
            with ruta.open('rb') as archivo:
                archivo.seek(-512, 2)
                if archivo.read(4) != b'koly':
                    raise ValueError(f'Imagen DMG incorrecta: {nombre}')
        elif ruta.suffix in {'.zip', '.apk'}:
            with zipfile.ZipFile(ruta) as archivo:
                if archivo.testzip() is not None:
                    raise ValueError(f'Archivo comprimido dañado: {nombre}')
                contenido = archivo.namelist()
                requerido = {'windows': 'glosala.exe', 'web': 'index.html',
                             'android': 'AndroidManifest.xml'}.get(plataforma)
                if requerido and requerido not in contenido:
                    raise ValueError(f'Falta {requerido} en {nombre}')
        elif nombre.endswith('.tar.gz'):
            with tarfile.open(ruta) as archivo:
                if 'glosala/glosala' not in archivo.getnames():
                    raise ValueError('El portable Linux no contiene el ejecutable.')
    return nombres


if __name__ == '__main__':
    argumentos = argparse.ArgumentParser(description=__doc__)
    argumentos.add_argument('plataforma', choices=[*esperados(version()), 'todos'])
    argumentos.add_argument('--carpeta', type=Path, default=SALIDA)
    opciones = argumentos.parse_args()
    nombres = verificar(opciones.carpeta, opciones.plataforma, version())
    print(f'{len(nombres)} paquetes completos y con formato válido.')
