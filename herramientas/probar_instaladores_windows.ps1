$ErrorActionPreference = 'Stop'
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

function Comprobar-Instalacion {
    foreach ($archivo in @('glosala.exe', 'flutter_windows.dll', 'vcruntime140.dll', 'data/flutter_assets/AssetManifest.bin')) {
        if (-not (Test-Path (Join-Path $carpeta $archivo))) { throw "Falta $archivo" }
    }
    $acceso = Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Glosala/Glosala.lnk'
    if (-not (Test-Path $acceso)) { throw 'Falta el acceso del menú Inicio' }
    $aplicacion = Start-Process (Join-Path $carpeta 'glosala.exe') -PassThru
    try {
        Start-Sleep -Seconds 5
        $aplicacion.Refresh()
        if ($aplicacion.HasExited) { throw "La aplicación no arranca: $($aplicacion.ExitCode)" }
        $aplicacion.CloseMainWindow() | Out-Null
        if (-not $aplicacion.WaitForExit(10000)) { Stop-Process -Id $aplicacion.Id }
    } finally {
        if (-not $aplicacion.HasExited) { Stop-Process -Id $aplicacion.Id -ErrorAction SilentlyContinue }
    }
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
