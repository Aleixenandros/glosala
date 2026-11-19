$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Esta prueba instala aplicaciones y solo debe ejecutarse en el runner del CI.' }
$version = (Select-String -Path pubspec.yaml -Pattern '^version: ([^+]+)').Matches.Groups[1].Value
$carpeta = Join-Path $env:ProgramFiles 'Glosala'
$msi = (Resolve-Path "distribucion/glosala-$version-windows-x64.msi").Path
$exe = (Resolve-Path "distribucion/glosala-$version-windows-x64-setup.exe").Path
$registros = Join-Path (Get-Location) 'build/instaladores/registros'
New-Item -ItemType Directory -Force $registros | Out-Null
$testigo = Join-Path $env:APPDATA 'app.glosala/Glosala/Glosala/vault/prueba-instalador.txt'
New-Item -ItemType Directory -Force (Split-Path $testigo) | Out-Null
Set-Content $testigo 'Conservar las notas del usuario'

function Ejecutar-Instalador($programa, $argumentos) {
    $proceso = Start-Process -FilePath $programa -ArgumentList $argumentos -Wait -PassThru
    if ($proceso.ExitCode -notin @(0, 3010)) {
        Get-ChildItem $registros -Filter '*.log' | ForEach-Object { Get-Content $_ -Tail 100 }
        throw "El instalador terminó con código $($proceso.ExitCode)"
    }
}

function Abrir-Aplicacion($ejecutable) {
    $aplicacion = Start-Process $ejecutable -PassThru
    try {
        Start-Sleep -Seconds 5
        $aplicacion.Refresh()
        if ($aplicacion.HasExited) { throw "La aplicación no arranca: $($aplicacion.ExitCode)" }
        $aplicacion.CloseMainWindow() | Out-Null
        if (-not $aplicacion.WaitForExit(10000)) { throw 'La aplicación instalada no se cierra correctamente' }
        Comprobar-Salida $aplicacion
    } finally {
        if (-not $aplicacion.HasExited) { Stop-Process -Id $aplicacion.Id -ErrorAction SilentlyContinue }
    }
}

function Comprobar-Salida($proceso) {
    if ($proceso.ExitCode -ne 0) {
        Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddMinutes(-5)} -ErrorAction SilentlyContinue |
            Where-Object Message -Match 'glosala|flutter_windows' | Select-Object TimeCreated, Message | Format-List | Out-String | Write-Output
        throw "La aplicación termina con código $($proceso.ExitCode)"
    }
}

function Comprobar-Instalacion {
    foreach ($archivo in @('glosala.exe', 'flutter_windows.dll', 'vcruntime140.dll', 'data/flutter_assets/AssetManifest.bin')) {
        if (-not (Test-Path (Join-Path $carpeta $archivo))) { throw "Falta $archivo" }
    }
    $acceso = Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Glosala/Glosala.lnk'
    if (-not (Test-Path $acceso)) { throw 'Falta el acceso del menú Inicio' }
    Abrir-Aplicacion (Join-Path $carpeta 'glosala.exe')
}

function Comprobar-Desinstalacion {
    if (Test-Path (Join-Path $carpeta 'glosala.exe')) { throw 'El ejecutable sigue instalado' }
    if ((Get-Content $testigo) -ne 'Conservar las notas del usuario') { throw 'Se han modificado los datos del usuario' }
}

Ejecutar-Instalador 'msiexec.exe' "/i `"$msi`" /qn /norestart /l*v `"$registros/msi-instalar.log`""
Comprobar-Instalacion
Ejecutar-Instalador 'msiexec.exe' "/x `"$msi`" /qn /norestart /l*v `"$registros/msi-quitar.log`""
Comprobar-Desinstalacion
Ejecutar-Instalador $exe "/install /quiet /norestart /log `"$registros/exe-instalar.log`""
Comprobar-Instalacion
Ejecutar-Instalador $exe "/uninstall /quiet /norestart /log `"$registros/exe-quitar.log`""
Comprobar-Desinstalacion
Write-Output 'MSI y EXE: instalación, arranque y desinstalación correctos; datos conservados.'

$portable = Join-Path $env:RUNNER_TEMP 'Glosala portable'
New-Item -ItemType Directory $portable | Out-Null
$nombrePortable = "glosala-$version-windows-x64_portable.exe"
Copy-Item "distribucion/$nombrePortable" $portable

function Abrir-Portable($directorio) {
    $lanzador = Start-Process (Join-Path $directorio $nombrePortable) -PassThru
    $hijo = $null
    try {
        for ($intento = 0; $intento -lt 60; $intento++) {
            Start-Sleep -Seconds 1
            $lanzador.Refresh()
            if ($lanzador.HasExited) { throw "El portable ha terminado antes de abrirse: $($lanzador.ExitCode)" }
            $hijo = Get-CimInstance Win32_Process -Filter "ParentProcessId = $($lanzador.Id) AND Name = 'glosala.exe'" | Select-Object -First 1
            if ($hijo) { break }
        }
        if (-not $hijo) { throw 'El EXE portable no ha abierto Glosala' }
        $aplicacion = Get-Process -Id $hijo.ProcessId
        Start-Sleep -Seconds 5
        $aplicacion.Refresh()
        if ($aplicacion.HasExited) { throw 'La aplicación portable se ha cerrado inesperadamente' }
        if (-not (Test-Path (Join-Path $directorio 'datos/boveda/workspace.json'))) {
            throw 'El portable no ha creado su bóveda junto al EXE original'
        }
        $aplicacion.CloseMainWindow() | Out-Null
        if (-not $aplicacion.WaitForExit(10000)) { throw 'La aplicación portable no se cierra correctamente' }
        if (-not $lanzador.WaitForExit(10000)) { throw 'El lanzador portable no termina al cerrar Glosala' }
        Comprobar-Salida $aplicacion
        Comprobar-Salida $lanzador
        if (Test-Path $hijo.ExecutablePath) { throw 'El portable no ha limpiado los binarios temporales' }
    } finally {
        if ($hijo) { Stop-Process -Id $hijo.ProcessId -ErrorAction SilentlyContinue }
        if (-not $lanzador.HasExited) { Stop-Process -Id $lanzador.Id -ErrorAction SilentlyContinue }
    }
}

Abrir-Portable $portable
$boveda = Join-Path $portable 'datos/boveda/workspace.json'
if (-not (Test-Path $boveda)) { throw 'El portable no ha creado su bóveda junto al ejecutable' }
$datos = Get-Content $boveda -Raw | ConvertFrom-Json -AsHashtable
$datos.preferencias['prueba_portable'] = 'Conservar al trasladar'
$datos | ConvertTo-Json -Depth 30 | Set-Content $boveda -Encoding utf8
$trasladado = Join-Path $env:RUNNER_TEMP 'Glosala trasladada'
Move-Item $portable $trasladado
Abrir-Portable $trasladado
$datos = Get-Content (Join-Path $trasladado 'datos/boveda/workspace.json') -Raw | ConvertFrom-Json -AsHashtable
if ($datos.preferencias['prueba_portable'] -ne 'Conservar al trasladar') { throw 'Se ha perdido la bóveda portable' }
Comprobar-Desinstalacion
Write-Output 'EXE portable: arranque autónomo, limpieza temporal y conservación de datos tras trasladar la carpeta correctos.'
