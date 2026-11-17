"""Comprueba instalación real en los runners desechables del CI."""
from pathlib import Path
import os
import plistlib
import subprocess
import sys

from empaquetar import RAIZ, SALIDA, ejecutar, version

if os.environ.get('GITHUB_ACTIONS') != 'true':
    raise SystemExit('Esta prueba instala paquetes y solo debe ejecutarse en el runner del CI.')

numero = version()
if sys.argv[1] == 'linux':
    paquete = SALIDA / f'glosala_{numero}_amd64.deb'
    ejecutar('sudo', 'apt-get', 'install', '-y', paquete)
    assert Path('/usr/bin/glosala').is_file()
    assert Path('/opt/glosala/lib/libflutter_linux_gtk.so').is_file()
    ejecutar('desktop-file-validate', '/usr/share/applications/app.glosala.glosala.desktop')
    resultado = subprocess.run(['timeout', '8s', 'xvfb-run', '-a', '/usr/bin/glosala'],
                               env={**os.environ, 'LIBGL_ALWAYS_SOFTWARE': '1',
                                    'XDG_DATA_HOME': str(RAIZ / 'build/instaladores/datos-prueba')})
    if resultado.returncode != 124:
        raise RuntimeError(f'La aplicación terminó antes de tiempo: {resultado.returncode}')
    ejecutar('sudo', 'apt-get', 'remove', '-y', 'glosala')
    assert not Path('/usr/bin/glosala').exists()
    # Las dependencias automáticas del RPM deben conservar GTK/mpv y no exigir
    # como paquetes separados el motor o los plugins que ya se incluyen.
    requisitos = ejecutar('rpm', '-qpR', SALIDA / f'glosala-{numero}-1.x86_64.rpm',
                          capture_output=True, text=True).stdout
    assert 'libmpv.so.2' in requisitos and 'libgtk-3.so.0' in requisitos
    assert 'libflutter_linux_gtk.so' not in requisitos
    assert 'libjvm.so' not in requisitos
elif sys.argv[1] == 'macos':
    montaje = RAIZ / 'build/instaladores/montaje'
    montaje.mkdir()
    ejecutar('hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', montaje,
             SALIDA / f'glosala-{numero}-macos.dmg')
    try:
        assert (montaje / 'glosala.app/Contents/MacOS/glosala').is_file()
        assert (montaje / 'Applications').is_symlink()
    finally:
        ejecutar('hdiutil', 'detach', montaje)
    ejecutar('sudo', 'installer', '-pkg', SALIDA / f'glosala-{numero}-macos.pkg', '-target', '/')
    aplicacion = Path('/Applications/glosala.app')
    datos = plistlib.loads((aplicacion / 'Contents/Info.plist').read_bytes())
    assert datos['CFBundleShortVersionString'] == numero
    assert (aplicacion / 'Contents/MacOS/glosala').is_file()
else:
    raise SystemExit('Plataforma no compatible.')
print('Instaladores comprobados correctamente.')
