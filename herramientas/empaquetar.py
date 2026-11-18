"""Crea los paquetes portables y los instaladores de cada plataforma."""
from pathlib import Path
import argparse
import os
import plistlib
import re
import shutil
import subprocess
import tarfile
import uuid
import xml.etree.ElementTree as ET
import zipfile

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / 'distribucion'
TEMPORAL = RAIZ / 'build/instaladores'
RUTAS = {
    'linux': 'build/linux/x64/release/bundle',
    'windows': 'build/windows/x64/runner/Release',
    'macos': 'build/macos/Build/Products/Release/glosala.app',
    'ios': 'build/ios/iphoneos/Runner.app',
    'web': 'build/web',
    'android': 'build/app/outputs/flutter-apk/app-release.apk',
}
ID_PRODUCTO = uuid.UUID('076f017e-a8ae-494d-aad8-c1797bb94fa3')


def version():
    return re.search(r'^version: ([0-9]+\.[0-9]+\.[0-9]+)',
                     (RAIZ / 'pubspec.yaml').read_text(), re.M)[1]


def ejecutar(*argumentos, **opciones):
    return subprocess.run([str(a) for a in argumentos], check=True, **opciones)


def preparar(plataforma):
    carpeta = TEMPORAL / plataforma
    if carpeta.exists():
        shutil.rmtree(carpeta)
    carpeta.mkdir(parents=True)
    SALIDA.mkdir(exist_ok=True)
    return carpeta


def zip_portable(origen, destino, extras=None):
    with zipfile.ZipFile(destino, 'w', zipfile.ZIP_DEFLATED) as archivo:
        for ruta in sorted(origen.rglob('*')):
            if ruta.is_file():
                archivo.write(ruta, ruta.relative_to(origen))
        for nombre, contenido in (extras or {}).items():
            archivo.writestr(nombre, contenido)


def linux(origen, numero):
    trabajo = preparar('linux')
    raiz = trabajo / 'raiz'
    aplicacion = raiz / 'opt/glosala'
    shutil.copytree(origen, aplicacion, symlinks=True)
    lanzador = raiz / 'usr/bin/glosala'
    lanzador.parent.mkdir(parents=True)
    lanzador.write_text('#!/bin/sh\nexec /opt/glosala/glosala "$@"\n')
    lanzador.chmod(0o755)
    escritorio = raiz / 'usr/share/applications/app.glosala.glosala.desktop'
    escritorio.parent.mkdir(parents=True)
    shutil.copy2(RAIZ / 'configuracion/instaladores/glosala.desktop', escritorio)
    icono = raiz / 'usr/share/icons/hicolor/512x512/apps/glosala.png'
    icono.parent.mkdir(parents=True)
    shutil.copy2(RAIZ / 'web/icons/Icon-512.png', icono)
    ejecutar('desktop-file-validate', escritorio)

    # Las bibliotecas privadas se resuelven en lib/ y carecen de ficha Debian.
    # dpkg calcula las versiones mínimas de las bibliotecas del sistema.
    debian = trabajo / 'debian'
    debian.mkdir()
    (debian / 'control').write_text(
        'Source: glosala\nSection: utils\nPriority: optional\n'
        'Maintainer: Aleixenandros <Aleixenandros@users.noreply.github.com>\n\n'
        'Package: glosala\nArchitecture: amd64\nDescription: Notas Markdown\n')
    binarios = []
    for archivo in aplicacion.rglob('*'):
        if archivo.is_file() and not archivo.is_symlink():
            with archivo.open('rb') as contenido:
                if contenido.read(4) == b'\x7fELF':
                    binarios.append(archivo)
    if not binarios:
        raise RuntimeError('No se han encontrado binarios ELF para Linux.')
    dependencias = ejecutar(
        'dpkg-shlibdeps', '--ignore-missing-info', '-O',
        f'-l{aplicacion / "lib"}', *(f'-e{b}' for b in binarios),
        cwd=trabajo, capture_output=True, text=True,
    ).stdout.strip().removeprefix('shlibs:Depends=')
    if not dependencias:
        raise RuntimeError('No se han podido calcular las dependencias Debian.')
    control = raiz / 'DEBIAN'
    control.mkdir()
    tamano = sum(a.stat().st_size for a in raiz.rglob('*') if a.is_file()) // 1024 + 1
    (control / 'control').write_text(
        f'Package: glosala\nVersion: {numero}\nArchitecture: amd64\n'
        'Section: utils\nPriority: optional\n'
        'Maintainer: Aleixenandros <Aleixenandros@users.noreply.github.com>\n'
        f'Installed-Size: {tamano}\nDepends: {dependencias}, libmpv2\n'
        'Homepage: https://github.com/Aleixenandros/glosala\n'
        'Description: Notas Markdown e ideas conectadas\n'
        ' Editor local con tareas, adjuntos y sincronizacion WebDAV.\n')
    ejecutar('dpkg-deb', '--build', '--root-owner-group', raiz,
             SALIDA / f'glosala_{numero}_amd64.deb')
    shutil.rmtree(control)

    # Excluir las bibliotecas privadas; conservar requisitos de símbolos del sistema.
    privadas = set()
    for binario in binarios:
        datos = ejecutar('readelf', '-d', binario, capture_output=True, text=True).stdout
        privadas.update(re.findall(r'\(SONAME\).*\[(.+?)\]', datos))
    patron = '^(' + '|'.join(re.escape(n) for n in sorted(privadas)) + r')(\(.*\))?$'
    especificacion = trabajo / 'glosala.spec'
    especificacion.write_text(
        '%global debug_package %{nil}\n%global __os_install_post %{nil}\n'
        '%global _build_id_links none\n'
        f'%global __requires_exclude {patron}\n'
        '%global __provides_exclude_from ^/opt/glosala/.*$\n'
        f'Name: glosala\nVersion: {numero}\nRelease: 1\n'
        'Summary: Notas Markdown e ideas conectadas\nLicense: Proprietary\n'
        'URL: https://github.com/Aleixenandros/glosala\nBuildArch: x86_64\n'
        'Requires: libmpv.so.2()(64bit)\n'
        '\n%description\nEditor local con tareas, adjuntos y sincronizacion WebDAV.\n'
        f'\n%install\nmkdir -p "%{{buildroot}}"\ncp -a "{raiz}/." "%{{buildroot}}/"\n'
        '\n%files\n%defattr(-,root,root,-)\n/opt/glosala\n/usr/bin/glosala\n'
        '/usr/share/applications/app.glosala.glosala.desktop\n'
        '/usr/share/icons/hicolor/512x512/apps/glosala.png\n')
    ejecutar('rpmbuild', '-bb', '--define', f'_topdir {trabajo / "rpm"}', especificacion)
    paquetes = list((trabajo / 'rpm/RPMS').rglob('*.rpm'))
    if len(paquetes) != 1:
        raise RuntimeError('No se ha generado un único paquete RPM.')
    shutil.copy2(paquetes[0], SALIDA / paquetes[0].name)
    with tarfile.open(SALIDA / 'glosala-linux.tar.gz', 'w:gz') as archivo:
        archivo.add(origen, arcname='glosala')


def identificador(prefijo, ruta):
    return prefijo + uuid.uuid5(ID_PRODUCTO, ruta).hex


def generar_msi(origen, numero, destino):
    espacio = 'http://wixtoolset.org/schemas/v4/wxs'
    ui = espacio + '/ui'
    ET.register_namespace('', espacio)
    ET.register_namespace('ui', ui)

    def nodo(padre, nombre, **atributos):
        return ET.SubElement(padre, f'{{{espacio}}}{nombre}', atributos)

    raiz = ET.Element(f'{{{espacio}}}Wix')
    paquete = nodo(raiz, 'Package', Name='Glosala', Manufacturer='Aleixenandros',
                   Version=numero, Language='1034', UpgradeCode=str(ID_PRODUCTO),
                   ProductCode=str(uuid.uuid5(ID_PRODUCTO, numero)), Scope='perMachine')
    nodo(paquete, 'MajorUpgrade', DowngradeErrorMessage='Ya hay una versión más reciente de Glosala instalada.')
    nodo(paquete, 'MediaTemplate', EmbedCab='yes')
    nodo(paquete, 'Launch', Condition='VersionNT64', Message='Glosala requiere Windows de 64 bits.')
    icono = RAIZ / 'windows/runner/resources/app_icon.ico'
    nodo(paquete, 'Icon', Id='IconoGlosala', SourceFile=str(icono))
    nodo(paquete, 'Property', Id='ARPPRODUCTICON', Value='IconoGlosala')
    nodo(paquete, 'Property', Id='ARPURLINFOABOUT', Value='https://github.com/Aleixenandros/glosala')
    carpeta = nodo(paquete, 'StandardDirectory', Id='ProgramFiles64Folder')
    aplicacion = nodo(carpeta, 'Directory', Id='INSTALLFOLDER', Name='Glosala')
    directorios = {'.': aplicacion}
    componentes = []
    for ruta in sorted(origen.rglob('*')):
        relativa = ruta.relative_to(origen)
        padre = directorios[relativa.parent.as_posix()]
        clave = relativa.as_posix()
        if ruta.is_dir():
            directorios[clave] = nodo(padre, 'Directory', Id=identificador('D', clave), Name=ruta.name)
        elif ruta.is_file():
            componente = identificador('C', clave)
            componentes.append(componente)
            contenedor = nodo(padre, 'Component', Id=componente,
                              Guid=str(uuid.uuid5(ID_PRODUCTO, 'archivo:' + clave)), Bitness='always64')
            archivo = nodo(contenedor, 'File', Id=identificador('F', clave), Source=str(ruta), KeyPath='yes')
            if clave == 'glosala.exe':
                nodo(archivo, 'Shortcut', Id='AbrirGlosala', Name='Glosala', Advertise='yes',
                     Directory='MenuGlosala', WorkingDirectory='INSTALLFOLDER', Icon='IconoGlosala')
                nodo(contenedor, 'RemoveFolder', Id='QuitarMenuGlosala', Directory='MenuGlosala', On='uninstall')
    inicio = nodo(paquete, 'StandardDirectory', Id='ProgramMenuFolder')
    nodo(inicio, 'Directory', Id='MenuGlosala', Name='Glosala')
    funcion = nodo(paquete, 'Feature', Id='AplicacionCompleta', Title='Glosala', Level='1')
    for componente in componentes:
        nodo(funcion, 'ComponentRef', Id=componente)
    ET.SubElement(paquete, f'{{{ui}}}WixUI', {'Id': 'WixUI_InstallDir', 'InstallDirectory': 'INSTALLFOLDER'})
    # No presentar una licencia inventada: el asistente pasa a elegir destino.
    interfaz = nodo(paquete, 'UI')
    nodo(interfaz, 'Publish', Dialog='WelcomeDlg', Control='Next', Event='NewDialog',
         Value='InstallDirDlg', Order='2', Condition='NOT Installed')
    nodo(interfaz, 'Publish', Dialog='InstallDirDlg', Control='Back', Event='NewDialog',
         Value='WelcomeDlg', Order='2')
    ET.indent(raiz)
    ET.ElementTree(raiz).write(destino, encoding='utf-8', xml_declaration=True)


def windows(origen, numero):
    trabajo = preparar('windows')
    # Runtime oficial junto al ejecutable: también funciona el MSI independiente.
    runtime = Path(os.environ['GLOSALA_VC_REDIST'])
    if not (runtime / 'vcruntime140.dll').is_file():
        raise RuntimeError('No se ha localizado el runtime x64 de Visual C++.')
    for biblioteca in runtime.glob('*.dll'):
        shutil.copy2(biblioteca, origen / biblioteca.name)
    fuente = trabajo / 'producto.wxs'
    generar_msi(origen, numero, fuente)
    msi = trabajo / f'glosala-{numero}-windows-x64.msi'
    ejecutar('wix', 'build', fuente, '-arch', 'x64', '-culture', 'es-es',
             '-ext', 'WixToolset.UI.wixext', '-o', msi)
    exe = trabajo / f'glosala-{numero}-windows-x64-setup.exe'
    ejecutar('wix', 'build', RAIZ / 'configuracion/instaladores/windows.wxs',
             '-arch', 'x64', '-ext', 'WixToolset.BootstrapperApplications.wixext',
             '-d', f'Version={numero}', '-d', f'Paquete={msi}',
             '-d', f'Icono={RAIZ / "windows/runner/resources/app_icon.ico"}', '-o', exe)
    for archivo in [msi, exe]:
        shutil.copy2(archivo, SALIDA / archivo.name)
    zip_portable(origen, SALIDA / f'glosala-{numero}-windows-x64-portable.zip', {
        'glosala.portable': 'Glosala guarda la bóveda en datos/boveda junto al ejecutable.\n',
        'LEEME-portable.txt': (
            f'Glosala {numero} — Windows portable\n\n'
            'Extrae todo el ZIP en una carpeta donde puedas escribir y abre glosala.exe.\n'
            'No necesita instalación ni permisos de administrador.\n'
            'Las notas, adjuntos y preferencias se guardan en datos/boveda.\n'
            'Cierra la aplicación antes de mover o copiar la carpeta completa.\n'
            'Para actualizar, sustituye los archivos de la aplicación conservando datos/.\n'
            'No borres el marcador glosala.portable: activa este almacenamiento local.\n'
            'Esta bóveda es independiente de la versión instalada.\n'
        ),
    })


def macos(origen, numero):
    trabajo = preparar('macos')
    imagen = trabajo / 'imagen'
    imagen.mkdir()
    ejecutar('ditto', origen, imagen / 'glosala.app')
    (imagen / 'Applications').symlink_to('/Applications')
    ejecutar('hdiutil', 'create', '-volname', f'Glosala {numero}', '-srcfolder', imagen,
             '-ov', '-format', 'UDZO', SALIDA / f'glosala-{numero}-macos.dmg')
    raiz = trabajo / 'raiz'
    (raiz / 'Applications').mkdir(parents=True)
    ejecutar('ditto', origen, raiz / 'Applications/glosala.app')
    componentes = trabajo / 'componentes.plist'
    ejecutar('pkgbuild', '--analyze', '--root', raiz, componentes)
    datos = plistlib.loads(componentes.read_bytes())
    for componente in datos:
        componente['BundleIsRelocatable'] = False
    componentes.write_bytes(plistlib.dumps(datos))
    ejecutar('pkgbuild', '--root', raiz, '--component-plist', componentes,
             '--identifier', 'app.glosala.glosala', '--version', numero,
             '--install-location', '/', SALIDA / f'glosala-{numero}-macos.pkg')
    ejecutar('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', origen,
             SALIDA / 'glosala-macos-sin-notarizar.zip')


def main():
    argumentos = argparse.ArgumentParser(description=__doc__)
    argumentos.add_argument('plataforma', choices=RUTAS)
    plataforma = argumentos.parse_args().plataforma
    origen = RAIZ / RUTAS[plataforma]
    if not origen.exists():
        raise SystemExit(f'No se ha encontrado el resultado: {origen}')
    SALIDA.mkdir(exist_ok=True)
    if plataforma in {'linux', 'windows', 'macos'}:
        globals()[plataforma](origen, version())
    elif plataforma == 'android':
        shutil.copy2(origen, SALIDA / 'glosala-android-pruebas.apk')
    elif plataforma == 'ios':
        ejecutar('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', origen,
                 SALIDA / 'glosala-ios-sin-firmar.zip')
    else:
        zip_portable(origen, SALIDA / 'glosala-web.zip')


if __name__ == '__main__':
    main()
