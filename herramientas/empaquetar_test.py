"""Regresiones del contrato de publicación y de las actualizaciones MSI."""
from pathlib import Path
import io
import tarfile
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

from empaquetar import generar_msi
from verificar_paquetes import verificar


class DistribucionTest(unittest.TestCase):
    def test_un_portable_no_sustituye_a_los_instaladores(self):
        with tempfile.TemporaryDirectory() as temporal:
            carpeta = Path(temporal)
            with tarfile.open(carpeta / 'glosala-linux.tar.gz', 'w:gz') as archivo:
                datos = bytes(range(256)) * 40
                entrada = tarfile.TarInfo('glosala/glosala')
                entrada.size = len(datos)
                archivo.addfile(entrada, io.BytesIO(datos))
            # Evitar que el tamaño comprimido sea el motivo de rechazo.
            with (carpeta / 'glosala-linux.tar.gz').open('ab') as archivo:
                archivo.write(b'\0' * 1024)
            with self.assertRaisesRegex(ValueError, r'glosala_0.2.1_amd64.deb'):
                verificar(carpeta, 'linux', '0.2.1')

    def test_rechaza_un_zip_renombrado_como_msi(self):
        with tempfile.TemporaryDirectory() as temporal:
            carpeta = Path(temporal)
            for nombre in ['glosala-0.2.1-windows-x64-portable.zip', 'glosala-0.2.1-windows-x64.msi']:
                with zipfile.ZipFile(carpeta / nombre, 'w') as archivo:
                    archivo.writestr('glosala.exe', b'MZ' + b'\0' * 2048)
                    for necesario in ['glosala.portable', 'vcruntime140.dll',
                                      'flutter_windows.dll', 'LEEME-portable.txt']:
                        archivo.writestr(necesario, 'prueba')
            with self.assertRaisesRegex(ValueError, 'Formato incorrecto'):
                verificar(carpeta, 'windows', '0.2.1')

    def test_msi_actualiza_el_producto_conservando_identidad_de_componentes(self):
        with tempfile.TemporaryDirectory() as temporal:
            carpeta = Path(temporal)
            origen = carpeta / 'binarios'
            (origen / 'data/acción & notas').mkdir(parents=True)
            (origen / 'glosala.exe').write_bytes(b'MZ')
            (origen / 'data/acción & notas/fuente.ttf').write_bytes(b'fuente')
            versiones = []
            for numero in ['0.2.1', '0.2.2']:
                destino = carpeta / f'{numero}.wxs'
                generar_msi(origen, numero, destino)
                versiones.append(ET.parse(destino))
            espacio = {'w': 'http://wixtoolset.org/schemas/v4/wxs'}
            anterior, nueva = [v.find('w:Package', espacio) for v in versiones]
            self.assertEqual(anterior.get('UpgradeCode'), nueva.get('UpgradeCode'))
            self.assertNotEqual(anterior.get('ProductCode'), nueva.get('ProductCode'))
            componentes = [{c.get('Id'): c.get('Guid') for c in v.findall('.//w:Component', espacio)}
                           for v in versiones]
            self.assertEqual(componentes[0], componentes[1])
            self.assertEqual(len(componentes[0]), 2)
            referencias = {c.get('Id') for c in nueva.findall('.//w:ComponentRef', espacio)}
            self.assertEqual(referencias, set(componentes[1]))
            self.assertEqual(nueva.find('.//w:Shortcut', espacio).get('Advertise'), 'yes')
            self.assertIsNotNone(nueva.find('w:MajorUpgrade', espacio))


if __name__ == '__main__':
    unittest.main()
