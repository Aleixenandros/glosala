#!/bin/bash
# Se ejecuta dentro del contenedor Fedora desechable del CI.
set -euo pipefail
dnf install -y --setopt=install_weak_deps=False /paquetes/*.rpm
rpm -q glosala
test -x /usr/bin/glosala
test -f /usr/share/applications/app.glosala.glosala.desktop
dependencias=$(LD_LIBRARY_PATH=/opt/glosala/lib ldd /opt/glosala/glosala /opt/glosala/lib/*.so)
case "$dependencias" in
  *"not found"*) printf '%s\n' "$dependencias"; exit 1 ;;
esac
mkdir -p /root/.local/share/Glosala/vault
printf 'Conservar notas\n' > /root/.local/share/Glosala/vault/prueba.txt
dnf remove -y glosala
test ! -e /usr/bin/glosala
test -f /root/.local/share/Glosala/vault/prueba.txt
printf 'RPM instalado y desinstalado; dependencias resueltas y datos conservados.\n'
