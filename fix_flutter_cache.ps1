if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Error "Ejecuta este script como Administrador."
  exit 1
}

$flutterPath = "C:\flutter"
$cachePath = Join-Path $flutterPath "bin\cache"
$temp = "$env:TEMP\sysinternals.zip"
$extractDir = "$env:TEMP\SysinternalsSuite"

Write-Host "1) Intentando descargar Sysinternals (si no existe)..."
if (-not (Test-Path "$extractDir\handle.exe")) {
  try {
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/SysinternalsSuite.zip" -OutFile $temp -UseBasicParsing -ErrorAction Stop
    Expand-Archive -Path $temp -DestinationPath $extractDir -Force
    Remove-Item $temp -Force
  } catch {
    Write-Warning "No se pudo descargar/extraer Sysinternals: $($_.Exception.Message)"
  }
} else {
  Write-Host "handle.exe ya presente."
}

$handleExe = "$extractDir\handle.exe"
$lockingPids = @()

if (Test-Path $handleExe) {
  Write-Host "2) Buscando procesos con handles en $cachePath ..."
  $output = & $handleExe -accepteula -nobanner $cachePath 2>&1
  foreach ($line in $output) {
    if ($line -match "pid: (\d+)") {
      $foundPid = [int]$matches[1]
      if ($foundPid -and ($lockingPids -notcontains $foundPid)) { $lockingPids += $foundPid }
    } elseif ($line -match "(\d+):") {
      if ($line -match "([0-9]+)\s+pid:") {
        $foundPid = [int]$matches[1]
        if ($foundPid -and ($lockingPids -notcontains $foundPid)) { $lockingPids += $foundPid }
      }
    }
  }
  if ($lockingPids.Count -eq 0) {
    Write-Host "No se encontraron PIDs bloqueando la ruta (según handle.exe)."
  } else {
    Write-Host "Procesos detectados que podrían bloquear archivos: $lockingPids"
    foreach ($foundPid in $lockingPids) {
      try {
        $proc = Get-Process -Id $foundPid -ErrorAction Stop
        Write-Host "PID $foundPid -> $($proc.ProcessName) (Id: $foundPid)."
      } catch {
        Write-Warning "PID $foundPid no encontrado o ya finalizado."
      }
    }
    $answer = Read-Host "¿Deseas detener estos procesos ahora? (y/N)"
    if ($answer -match '^[Yy]') {
      foreach ($foundPid in $lockingPids) {
        try {
          Stop-Process -Id $foundPid -Force -ErrorAction Stop
          Write-Host "Detenido PID $foundPid"
        } catch {
          Write-Warning ("No se pudo detener PID {0}: {1}" -f $foundPid, $_.Exception.Message)
        }
      }
    } else {
      Write-Host "No se detuvieron procesos. Continúa con los pasos de permisos."
    }
  }
} else {
  Write-Warning "handle.exe no está disponible; seguiré con icacls y eliminación."
}

Write-Host "3) Tomando propiedad y estableciendo permisos en $flutterPath ..."
cmd /c "icacls \"$flutterPath\" /setowner \"$env:USERNAME\" /T /C" | Out-Null
cmd /c "icacls \"$flutterPath\" /grant \"$env:USERNAME\":(OI)(CI)F /T" | Out-Null

Write-Host "4) Quitando atributos de solo lectura/oculto si existen..."
Get-ChildItem -Path $flutterPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
  try { $_.Attributes = ($_.Attributes -band -bnot [System.IO.FileAttributes]::ReadOnly) } catch {}
}

Write-Host "5) Intentando eliminar la carpeta de cache..."
try {
  Remove-Item -LiteralPath $cachePath -Recurse -Force -ErrorAction Stop
  Write-Host "Cache eliminada: $cachePath"
} catch {
  Write-Warning ("No se pudo eliminar la caché directamente: {0}. Intentando fallback con rd..." -f $_.Exception.Message)
  cmd /c "rd /s /q \"$cachePath\"" | Out-Null
  if (-not (Test-Path $cachePath)) { Write-Host "Cache eliminada con rd." } else { Write-Warning "Aún no fue posible eliminar la caché." }
}

Write-Host "6) Ejecutando flutter precache para regenerar artefactos..."
$flutterBat = Join-Path $flutterPath "bin\flutter.bat"
if (Test-Path $flutterBat) {
  & $flutterBat precache
} else {
  Write-Warning "No se encontró $flutterBat. Asegúrate de que Flutter está instalado en $flutterPath."
}

Write-Host "Proceso completado. Revisa mensajes arriba para errores. Luego prueba 'flutter doctor -v' y 'flutter build web'."
