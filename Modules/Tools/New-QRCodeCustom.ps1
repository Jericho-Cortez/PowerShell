function New-QRCodeCustom {
    Write-Host "`n📱 GÉNÉRATEUR DE QR CODE" -ForegroundColor Cyan
    Write-Host "═══════════════════════════" -ForegroundColor Cyan
    
    $pythonScript = "C:\Users\jbcde\Documents\Projet\PowerShell\Code\qrcode_generator.py"
    
    if (-not (Test-Path $pythonScript)) {
        Write-Host "❌ Script Python introuvable: $pythonScript" -ForegroundColor Red
        Write-Host "💡 Crée le fichier à cet emplacement d'abord" -ForegroundColor Yellow
        Read-Host "`nAppuie sur Entrée"
        return
    }
    
    $Text = Read-Host "`nEntre l'URL"
    
    if ([string]::IsNullOrEmpty($Text)) {
        Write-Host "❌ Aucune URL fournie" -ForegroundColor Red
        Read-Host "Appuie sur Entrée"
        return
    }
    
    $customName = Read-Host "`nNom du fichier (laisser vide pour auto-générer)"
    
    $outputPath = ""
    if (-not [string]::IsNullOrEmpty($customName)) {
        $qr_folder = "C:\Users\jbcde\OneDrive\Documents\QR_Code"
        if (-not $customName.EndsWith('.png')) {
            $customName = "$customName.png"
        }
        $outputPath = Join-Path $qr_folder $customName
    }
    
    Write-Host "`n🔄 Génération du QR Code..." -ForegroundColor Yellow
    
    try {
        if ([string]::IsNullOrEmpty($outputPath)) {
            $result = & python "$pythonScript" "$Text" 2>&1
        }
        else {
            $result = & python "$pythonScript" "$Text" "$outputPath" 2>&1
        }
    }
    catch {
        Write-Host "❌ Erreur d'exécution: $_" -ForegroundColor Red
        Read-Host "`nAppuie sur Entrée"
        return
    }
    
    if ($result -match "SUCCESS:(.+)") {
        $outputPath = $Matches[1]
        Write-Host "✅ QR Code créé avec succès !" -ForegroundColor Green
        Write-Host "📁 Emplacement: $outputPath" -ForegroundColor Cyan
        Start-Process $outputPath
    }
    elseif ($result -match "ERROR:(.+)") {
        $erreur = $Matches[1]
        Write-Host "❌ Erreur: $erreur" -ForegroundColor Red
    }
    else {
        Write-Host "❌ Erreur inconnue" -ForegroundColor Red
        Write-Host "Détails: $result" -ForegroundColor Gray
    }
    
    Read-Host "`nAppuie sur Entrée"
}