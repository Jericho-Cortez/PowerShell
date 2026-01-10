function Sort-Downloads {
    Write-Host "`n🗂️ TRI AUTOMATIQUE TÉLÉCHARGEMENTS" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════" -ForegroundColor Cyan
    
    $downloads = "$env:USERPROFILE\Downloads"
    
    # Vérifier si le dossier existe
    if (-not (Test-Path $downloads)) {
        Write-Host "`n❌ Dossier Downloads introuvable" -ForegroundColor Red
        Read-Host "Appuie sur Entrée"
        return
    }
    
    Write-Host "`n📂 Dossier : $downloads" -ForegroundColor Yellow
    
    # Catégories et extensions
    $categories = @{
        '📸 Images' = @('*.jpg','*.jpeg','*.png','*.gif','*.bmp','*.webp','*.svg')
        '🎬 Vidéos' = @('*.mp4','*.mkv','*.avi','*.mov','*.wmv','*.flv','*.webm')
        '📄 Documents' = @('*.pdf','*.docx','*.doc','*.xlsx','*.xls','*.txt','*.pptx')
        '📦 Archives' = @('*.zip','*.rar','*.7z','*.tar','*.gz')
        '💻 Code' = @('*.py','*.ps1','*.js','*.html','*.css','*.json','*.xml')
        '🎵 Audio' = @('*.mp3','*.wav','*.flac','*.m4a','*.aac')
        '⚙️ Executables' = @('*.exe','*.msi','*.apk')
    }
    
    Write-Host "`n🔄 Tri en cours..." -ForegroundColor Yellow
    
    $moved = 0
    $errors = 0
    
    foreach ($cat in $categories.Keys) {
        $folderName = $cat -replace '^.. ', ''  # Enlever emoji du nom dossier
        $folder = "$downloads\$folderName"
        
        # Créer le dossier
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
            Write-Host "   ✅ Dossier '$folderName' créé" -ForegroundColor Green
        }
        
        # Déplacer les fichiers
        foreach ($ext in $categories[$cat]) {
            $files = Get-ChildItem -Path $downloads -Filter $ext -File -ErrorAction SilentlyContinue
            
            foreach ($file in $files) {
                try {
                    Move-Item -Path $file.FullName -Destination $folder -Force -ErrorAction Stop
                    $moved++
                    Write-Host "   → $($file.Name)" -ForegroundColor Gray
                } catch {
                    $errors++
                    Write-Host "   ⚠️  Erreur : $($file.Name)" -ForegroundColor Red
                }
            }
        }
    }
    
    # Résumé
    Write-Host "`n📊 RÉSUMÉ" -ForegroundColor Magenta
    Write-Host "═════════" -ForegroundColor Magenta
    Write-Host "✅ Fichiers déplacés : $moved" -ForegroundColor Green
    if ($errors -gt 0) {
        Write-Host "⚠️  Erreurs : $errors" -ForegroundColor Yellow
    }
    
    # Ouvrir l'explorateur
    Write-Host "`n📂 Ouvrir Downloads ? (O/N)" -ForegroundColor Cyan
    $open = Read-Host
    
    if ($open -eq 'O' -or $open -eq 'o') {
        explorer $downloads
    }
    
    Read-Host "`nAppuie sur Entrée pour retourner au menu"
}