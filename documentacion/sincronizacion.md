# Sincronización de notas

## WebDAV

1. Crea una carpeta dedicada en Nextcloud, ownCloud o el servicio WebDAV de tu NAS.
2. Abre **Sincronización → WebDAV** e introduce la URL de esa carpeta, el usuario y una contraseña de aplicación.
3. Pulsa **Sincronizar ahora** en cada dispositivo.

Glosala lee y escribe `glosala-boveda.json`. No modifica archivos ajenos de la carpeta. La contraseña permanece solo en memoria mientras el panel está abierto; la URL y el usuario se guardan localmente. Usa HTTPS cuando envíes credenciales.

El servidor debe admitir GET, PUT y precondiciones HTTP. Si existe el documento, debe proporcionar un ETag fuerte; la escritura utiliza `If-Match`. En la primera escritura se utiliza `If-None-Match: *`. Un cambio concurrente produce un error recuperable; vuelve a sincronizar para obtener la nueva versión. Los redireccionamientos no se siguen automáticamente para no reenviar credenciales a otro destino.

Desde web, el servidor debe permitir CORS desde el origen de Glosala: métodos GET/PUT, cabeceras Authorization, Content-Type, If-Match e If-None-Match, y `Access-Control-Expose-Headers: ETag`. También debe atender la preconsulta OPTIONS. Una aplicación web HTTPS no puede conectarse a un servidor HTTP bloqueado como contenido mixto.

## Carpeta o NAS

En Linux, Windows o macOS, monta el recurso SMB/NFS mediante el sistema operativo. Selecciona su carpeta desde **Sincronización → Carpeta / NAS**. No es un cliente SMB incorporado. Esta opción utiliza bloqueo de archivo y comparación de la versión previa; el NAS debe respetar esos bloqueos. Las carpetas montadas no están disponibles desde web ni desde los selectores móviles de esta primera versión.

## Conflictos

Cada dispositivo conserva la huella de la última versión compartida. Si solo cambia una copia se propaga el cambio. Si cambian ambas se conservan la nota local y una copia remota con un identificador de conflicto. Puedes compararlas, reunir el contenido y mover la copia sobrante a la papelera. La primera conexión a un destino con versiones distintas también conserva ambas copias.

Las eliminaciones se propagan como estado de papelera, nunca como borrado irreversible. No se sincronizan tareas, preferencias, catálogos personalizados ni credenciales. El transporte cifra en tránsito únicamente cuando se usa HTTPS; no hay cifrado de extremo a extremo del documento remoto.

Las pruebas del proyecto ejecutan un servidor HTTP local para comprobar autorización y ETag, y dos bóvedas sobre una carpeta temporal para comprobar intercambio y conflictos. Una configuración concreta de NAS debe probarse con su servidor real.
