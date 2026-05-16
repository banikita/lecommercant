# setup_web.ps1
# Lance ce script UNE SEULE FOIS depuis le dossier racine du projet
# Il copie sqflite_sw.js et sqlite3.wasm dans web/

Write-Host "=== Setup SQLite Web Binaries ===" -ForegroundColor Cyan

# 1. Copier les binaires sqflite dans web/
dart run sqflite_common_ffi_web:setup

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅  sqflite_sw.js et sqlite3.wasm copiés dans web/" -ForegroundColor Green
} else {
    Write-Host "❌  Erreur lors du setup. Essaie : flutter pub get puis relance ce script." -ForegroundColor Red
    exit 1
}

# 2. Vérifier que les fichiers sont bien là
$files = @("web\sqflite_sw.js", "web\sqlite3.wasm")
foreach ($f in $files) {
    if (Test-Path $f) {
        Write-Host "✅  $f présent" -ForegroundColor Green
    } else {
        Write-Host "⚠️   $f MANQUANT — relance dart run sqflite_common_ffi_web:setup" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Terminé. Lance maintenant : flutter run -d edge ===" -ForegroundColor Cyan