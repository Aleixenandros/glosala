"""Empaqueta binarios completos, sin depender de herramientas del shell."""
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

plataforma = sys.argv[1]
salida = Path('distribucion')
salida.mkdir(exist_ok=True)
rutas = {
    'linux': Path('build/linux/x64/release/bundle'),
    'windows': Path('build/windows/x64/runner/Release'),
    'macos': Path('build/macos/Build/Products/Release/glosala.app'),
    'ios': Path('build/ios/iphoneos/Runner.app'),
    'web': Path('build/web'),
    'android': Path('build/app/outputs/flutter-apk/app-release.apk'),
}
origen = rutas[plataforma]
if not origen.exists():
    raise SystemExit(f'No se ha encontrado el resultado: {origen}')
if plataforma == 'android':
    shutil.copy2(origen, salida / 'glosala-android-pruebas.apk')
elif plataforma == 'linux':
    with tarfile.open(salida / 'glosala-linux.tar.gz', 'w:gz') as archivo:
        archivo.add(origen, arcname='glosala')
elif plataforma in {'macos', 'ios'}:
    # ditto conserva permisos, enlaces y atributos de los paquetes de Apple.
    nombre = 'glosala-ios-sin-firmar.zip' if plataforma == 'ios' else 'glosala-macos-sin-notarizar.zip'
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(origen), str(salida / nombre)], check=True)
else:
    with zipfile.ZipFile(salida / f'glosala-{plataforma}.zip', 'w', zipfile.ZIP_DEFLATED) as archivo:
        for ruta in sorted(origen.rglob('*')):
            if ruta.is_file():
                archivo.write(ruta, ruta.relative_to(origen))
