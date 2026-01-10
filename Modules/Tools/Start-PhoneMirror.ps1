function Start-PhoneMirror {
    Write-Host "`n📱 MIROIR D'ÉCRAN TÉLÉPHONE" -ForegroundColor Cyan
    Write-Host "═══════════════════════════" -ForegroundColor Cyan
    
    # Vérifier si scrcpy est installé
    if (-not (Get-Command scrcpy -ErrorAction SilentlyContinue)) {
        Write-Host "`n⚠️  scrcpy non installé" -ForegroundColor Yellow
        Write-Host "💡 scrcpy permet d'afficher et contrôler ton téléphone Android via USB" -ForegroundColor Cyan
        
        Write-Host "`n📦 Installation :" -ForegroundColor Yellow
        Write-Host "   winget install Genymobile.scrcpy" -ForegroundColor White
        
        $install = Read-Host "`nInstaller maintenant ? (O/N)"
        
        if ($install -eq 'O' -or $install -eq 'o') {
            Write-Host "`n🔄 Installation en cours..." -ForegroundColor Cyan
            winget install Genymobile.scrcpy --accept-package-agreements --accept-source-agreements
            
            Write-Host "`n✅ Installation terminée !" -ForegroundColor Green
            Write-Host "💡 Relance cette fonction après avoir branché ton téléphone" -ForegroundColor Cyan
        }
        
        Read-Host "`nAppuie sur Entrée"
        return
    }
    
    # Vérifier si un téléphone est connecté
    Write-Host "`n🔍 Recherche de téléphone connecté..." -ForegroundColor Yellow
    
    # Vérifier si adb détecte un appareil
    $adbCheck = adb devices 2>&1
    $devices = $adbCheck | Select-String "device$" | Where-Object { $_ -notmatch "List of devices" }
    
    if (-not $devices) {
        Write-Host "`n⚠️  Aucun téléphone détecté" -ForegroundColor Yellow
        Write-Host "`n📋 Prérequis :" -ForegroundColor Cyan
        Write-Host "   1. Brancher le téléphone en USB-C" -ForegroundColor White
        Write-Host "   2. Activer le débogage USB sur ton téléphone :" -ForegroundColor White
        Write-Host "      • Paramètres > À propos du téléphone" -ForegroundColor Gray
        Write-Host "      • Taper 7x sur 'Numéro de build'" -ForegroundColor Gray
        Write-Host "      • Paramètres > Options développeur" -ForegroundColor Gray
        Write-Host "      • Activer 'Débogage USB'" -ForegroundColor Gray
        Write-Host "   3. Autoriser le PC sur le téléphone" -ForegroundColor White
        
        Read-Host "`nAppuie sur Entrée"
        return
    }
    
    Write-Host "✅ Téléphone détecté !" -ForegroundColor Green
    
    # Options de lancement
    Write-Host "`n📋 Mode d'affichage :" -ForegroundColor Yellow
    Write-Host "  [1] Normal (résolution téléphone)" -ForegroundColor White
    Write-Host "  [2] HD (1920x1080)" -ForegroundColor White
    Write-Host "  [3] Performance (réduction qualité)" -ForegroundColor White
    Write-Host "  [4] Pas de contrôle (affichage seul)" -ForegroundColor White
    Write-Host "  [5] Enregistrer l'écran" -ForegroundColor White
    
    $mode = Read-Host "`nChoix (1-5)"
    
    Write-Host "`n🚀 Lancement du miroir..." -ForegroundColor Cyan
    Write-Host "💡 Raccourcis utiles :" -ForegroundColor Gray
    Write-Host "   • Ctrl+O : Éteindre l'écran du téléphone" -ForegroundColor DarkGray
    Write-Host "   • Ctrl+N : Ouvrir les notifications" -ForegroundColor DarkGray
    Write-Host "   • Ctrl+B : Retour" -ForegroundColor DarkGray
    Write-Host "   • Ctrl+H : Home" -ForegroundColor DarkGray
    Write-Host "   • Ctrl+S : Applications récentes" -ForegroundColor DarkGray
    Write-Host ""
    
    Start-Sleep -Seconds 1
    
    try {
        switch ($mode) {
            '1' {
                # Mode normal
                scrcpy 
            }
            '2' {
                # HD 1080p
                scrcpy --max-size 1920 
            }
            '3' {
                # Performance (bitrate réduit + FPS limité)
                scrcpy --max-size 1280 --max-fps 30 --bit-rate 2M 
            }
            '4' {
                # Affichage seul (pas de contrôle)
                scrcpy --no-control 
            }
            '5' {
                # Enregistrement
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $recordPath = "$env:USERPROFILE\Videos\phone_$timestamp.mp4"
                
                Write-Host "📹 Enregistrement vers : $recordPath" -ForegroundColor Cyan
                scrcpy --record=$recordPath
                
                Write-Host "`n✅ Enregistrement sauvegardé : $recordPath" -ForegroundColor Green
            }
            default {
                scrcpy
            }
        }
    }
    catch {
        Write-Host "`n❌ Erreur lors du lancement" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Gray
    }
    
    Read-Host "`nAppuie sur Entrée pour retourner au menu"
}