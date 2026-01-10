function Get-YouTubeVideo {
    Write-Host "`n📥 TÉLÉCHARGEUR YOUTUBE" -ForegroundColor Cyan
    Write-Host "═══════════════════════" -ForegroundColor Cyan
    
    # Vérifier si yt-dlp est installé
    if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
        Write-Host "`n⚠️  yt-dlp non installé" -ForegroundColor Yellow
        Write-Host "💡 yt-dlp permet de télécharger des vidéos YouTube, TikTok, Instagram, etc." -ForegroundColor Cyan
        
        Write-Host "`n📦 Installation :" -ForegroundColor Yellow
        Write-Host "   winget install yt-dlp.yt-dlp" -ForegroundColor White
        
        $install = Read-Host "`nInstaller maintenant ? (O/N)"
        
        if ($install -eq 'O' -or $install -eq 'o') {
            Write-Host "`n🔄 Installation en cours..." -ForegroundColor Cyan
            winget install yt-dlp.yt-dlp --accept-package-agreements --accept-source-agreements
            
            Write-Host "`n✅ Installation terminée !" -ForegroundColor Green
            Write-Host "💡 Relance cette fonction pour télécharger" -ForegroundColor Cyan
        }
        
        Read-Host "`nAppuie sur Entrée"
        return
    }
    
    # Demander l'URL
    $url = Read-Host "`n🔗 URL de la vidéo (YouTube, TikTok, Instagram...)"
    
    if ([string]::IsNullOrWhiteSpace($url)) {
        Write-Host "❌ URL invalide" -ForegroundColor Red
        Read-Host "Appuie sur Entrée"
        return
    }
    
    # Options de téléchargement
    Write-Host "`n📋 Options de téléchargement :" -ForegroundColor Yellow
    Write-Host "  [1] 🎬 Vidéo Meilleure qualité (1080p+)" -ForegroundColor White
    Write-Host "  [2] 📱 Vidéo Moyenne qualité (720p)" -ForegroundColor White
    Write-Host "  [3] 🎵 Audio seulement (MP3)" -ForegroundColor White
    Write-Host "  [4] 🎥 Playlist complète" -ForegroundColor White
    
    $quality = Read-Host "`nChoix (1-4)"
    
    # Dossier de destination
    $outputFolder = "$env:USERPROFILE\Videos\YouTube"
    if (-not (Test-Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
        Write-Host "`n✅ Dossier créé : $outputFolder" -ForegroundColor Green
    }
    
    $output = "$outputFolder\%(title)s.%(ext)s"
    
    Write-Host "`n🔄 Téléchargement en cours..." -ForegroundColor Cyan
    Write-Host "📂 Destination : $outputFolder" -ForegroundColor Gray
    Write-Host ""
    
    try {
        $downloadedFile = $null
        
        switch ($quality) {
            '1' { 
                yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" --merge-output-format mp4 -o $output $url
            }
            '2' { 
                yt-dlp -f "best[height<=720][ext=mp4]/best[height<=720]/best" -o $output $url
            }
            '3' { 
                # ⭐ MODE AUDIO AVEC RÉSUMÉ OLLAMA
                Write-Host "🎵 Téléchargement audio..." -ForegroundColor Cyan
                
                # Récupérer le titre de la vidéo
                $videoInfo = yt-dlp --get-title $url 2>$null
                $safeTitle = $videoInfo -replace '[^\w\s-]', '' -replace '\s+', '_'
                $audioFile = "$outputFolder\$safeTitle.mp3"
                
                yt-dlp -x --audio-format mp3 --audio-quality 0 -o $audioFile $url
                $downloadedFile = $audioFile
                
                Write-Host "`n✅ Audio téléchargé !" -ForegroundColor Green
                
                # ⭐ PROPOSITION DE RÉSUMÉ AUTOMATIQUE
                Write-Host "`n🤖 Générer un résumé automatique avec IA locale ? (O/N)" -ForegroundColor Yellow
                Write-Host "💡 Whisper + Ollama (Llama2) - Gratuit et privé" -ForegroundColor Cyan
                $summarize = Read-Host
                
                if ($summarize -eq 'O' -or $summarize -eq 'o') {
                    Write-Host "`n🧠 Génération du résumé avec Llama2..." -ForegroundColor Cyan
                    
                    # Vérifier Ollama
                    try {
                        $ollamaCheck = Invoke-WebRequest -Uri "http://localhost:11434/api/version" -ErrorAction Stop | ConvertFrom-Json
                        Write-Host "✅ Ollama détecté" -ForegroundColor Green
                    } catch {
                        Write-Host "❌ Ollama n'est pas lancé !" -ForegroundColor Red
                        Write-Host "💡 Ouvre une PowerShell et lance: ollama serve" -ForegroundColor Yellow
                        Read-Host "Appuie sur Entrée"
                        return
                    }
                    
                    # Extraction sous-titres
                    Write-Host "📝 Extraction de contenu..." -ForegroundColor Cyan
                    
                    $subFiles = @()
                    yt-dlp --write-auto-sub --sub-lang fr,en --skip-download -o "$outputFolder\$safeTitle" $url 2>$null
                    
                    $subFiles = @(Get-ChildItem "$outputFolder\$safeTitle*.vtt" -ErrorAction SilentlyContinue)
                    
                    if ($subFiles.Count -gt 0) {
                        $rawSubContent = Get-Content $subFiles[0].FullName -Raw
                        
                        # Parser sous-titres avec timestamps
                        $transcriptLines = @()
                        $lines = $rawSubContent -split "`n"
                        $currentTimestamp = ""
                        $timestamps = @()
                        
                        foreach ($line in $lines) {
                            $trimmedLine = $line.Trim()
                            
                            if ($trimmedLine -match '^(\d{2}:\d{2}:\d{2}).*?(\d{2}:\d{2}:\d{2})') {
                                $currentTimestamp = $matches[1]
                                $timestamps += $currentTimestamp
                            }
                            elseif ($trimmedLine -and -not ($trimmedLine -match '^\d+$')) {
                                if ($currentTimestamp -and $trimmedLine) {
                                    $transcriptLines += "[$currentTimestamp] $trimmedLine"
                                }
                            }
                        }
                        
                        # Nettoyer doublons
                        if ($transcriptLines.Count -gt 0) {
                            $cleanedLines = @()
                            $lastText = ""
                            foreach ($tline in $transcriptLines) {
                                $textOnly = $tline -replace '^\[.*?\]\s+', ''
                                if ($textOnly -ne $lastText) {
                                    $cleanedLines += $tline
                                    $lastText = $textOnly
                                }
                            }
                            $transcContent = $cleanedLines -join "`n"
                            $duration = if ($timestamps.Count -gt 0) { $timestamps[-1] } else { "[Non disponible]" }
                        } else {
                            $transcContent = $rawSubContent
                            $duration = "[Non disponible]"
                        }
                    } else {
                        # Fallback Whisper
                        Write-Host "`n⚠️  Pas de sous-titres disponibles" -ForegroundColor Yellow
                        Write-Host "💡 Tentative de transcription avec Whisper..." -ForegroundColor Cyan
                        
                        $whisperCheck = Get-Command whisper -ErrorAction SilentlyContinue
                        
                        if ($whisperCheck) {
                            Write-Host "🎤 Transcription en cours (2-5 minutes)..." -ForegroundColor Yellow
                            
                            try {
                                whisper "$audioFile" --output_format txt --output_dir "$outputFolder" --language fr --device cuda 2>&1 | Out-Null
                                
                                $whisperTxt = Get-ChildItem "$outputFolder\$safeTitle.txt" -ErrorAction SilentlyContinue
                                
                                if ($whisperTxt) {
                                    $transcContent = Get-Content $whisperTxt.FullName -Raw
                                    $duration = "Transcription Whisper"
                                    Write-Host "✅ Transcription réussie !" -ForegroundColor Green
                                }
                                else {
                                    $transcContent = "Vidéo YouTube - $videoInfo`n[Transcription non disponible]"
                                    $duration = "[Non disponible]"
                                }
                            }
                            catch {
                                $transcContent = "Vidéo YouTube - $videoInfo"
                                $duration = "[Non disponible]"
                            }
                        }
                        else {
                            Write-Host "`n⚠️  Whisper non installé" -ForegroundColor Yellow
                            $transcContent = Read-Host "💡 Décris le contenu (ou Entrée)"
                            $duration = "[Durée non calculable]"
                            
                            if ([string]::IsNullOrWhiteSpace($transcContent)) {
                                $transcContent = "Vidéo YouTube - $videoInfo"
                            }
                        }
                    }
                    
                    # Charger prompt
                    $promptFile = "C:\Users\jbcde\OneDrive\Documents\Ollama\Prompt_resumer_video.txt"
                    
                    if (-not (Test-Path $promptFile)) {
                        Write-Host "❌ Fichier prompt introuvable: $promptFile" -ForegroundColor Red
                        Read-Host "Appuie sur Entrée"
                        return
                    }
                    
                    $promptTemplate = Get-Content $promptFile -Raw
                    
                    $prompt = $promptTemplate -replace '\$videoInfo', $videoInfo `
                                              -replace '\$url', $url `
                                              -replace '\$duration', $duration `
                                              -replace '\$transcContent', $transcContent
                    
                    # Appel Ollama
                    Write-Host "`n🔄 Appel du modèle Llama2... (3-5 minutes)" -ForegroundColor Gray
                    
                    $ollamaRequest = @{
                        model = "llama2"
                        prompt = $prompt
                        stream = $false
                    } | ConvertTo-Json -Depth 100
                    
                    try {
                        $response = Invoke-WebRequest -Uri "http://localhost:11434/api/generate" `
                            -Method Post `
                            -ContentType "application/json" `
                            -Body $ollamaRequest `
                            -TimeoutSec 1200 `
                            -ErrorAction Stop
                        
                        $responseData = $response.Content | ConvertFrom-Json
                        $resumeGenere = $responseData.response
                        
                        # Créer fichier résumé
                        $summaryFile = "$outputFolder\$safeTitle`_RESUME.txt"
                        
                        $finalSummary = @"
📝 RÉSUMÉ VIDÉO YOUTUBE - $videoInfo
═══════════════════════════════════════════════════════════

🔗 URL : $url
📅 Date : $(Get-Date -Format "dd/MM/yyyy HH:mm")
🎵 Fichier audio : $safeTitle.mp3

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📖 RÉSUMÉ (généré par Llama2):
────────────────────────────────
$resumeGenere

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 TRANSCRIPTION ORGANISÉE PAR TIMESTAMPS:
───────────────────────────────────────────

$transcContent
"@
                        
                        $finalSummary | Out-File -FilePath $summaryFile -Encoding UTF8
                        
                        Write-Host "`n✅ Résumé créé !" -ForegroundColor Green
                        Write-Host "📂 Fichier : $summaryFile" -ForegroundColor Cyan
                        
                        # ════════════════════════════════════════════════════════════
                        # ⭐ RÉORGANISATION AUTOMATIQUE
                        # ════════════════════════════════════════════════════════════
                        
                        Write-Host "`n🔄 Réorganisation automatique..." -ForegroundColor Cyan
                        
                        $compactFile = $summaryFile -replace '\.txt$', '_COMPACT.txt'
                        
                        try {
                            $content = Get-Content $summaryFile -Raw -Encoding UTF8
                            $lines = $content -split "`r?`n"
                            
                            $beforeSource = ""
                            $sourceContent = ""
                            $foundSource = $false
                            $foundData = $false
                            
                            foreach ($line in $lines) {
                                if ($line -match '📄\s*(SOURCE|TRANSCRIPTION)') {
                                    $foundSource = $true
                                    $beforeSource += $line + "`n"
                                    continue
                                }
                                
                                if ($foundSource -and $line -match '\[[\d:\.]+\]' -and -not $foundData) {
                                    $foundData = $true
                                }
                                
                                if ($foundData) {
                                    $sourceContent += $line + "`n"
                                } else {
                                    $beforeSource += $line + "`n"
                                }
                            }
                            
                            function Clean-Text($text) {
                                $text -replace '<[\d:\.]+>|</?c>', '' -replace '\s+', ' ' | ForEach-Object { $_.Trim() }
                            }
                            
                            $entries = @()
                            foreach ($line in ($sourceContent -split "`r?`n")) {
                                if ($line -match '\[(\d{2}):(\d{2}):(\d{2})') {
                                    $totalSec = [int]$matches[1] * 3600 + [int]$matches[2] * 60 + [int]$matches[3]
                                    $text = Clean-Text ($line -replace '^\[[\d:\.]+\]', '')
                                    
                                    if ($text.Length -gt 10) {
                                        $entries += [PSCustomObject]@{
                                            Time = "{0:D2}:{1:D2}:{2:D2}" -f $matches[1], $matches[2], $matches[3]
                                            Seconds = $totalSec
                                            Text = $text
                                        }
                                    }
                                }
                            }
                            
                            if ($entries.Count -gt 0) {
                                $entries = $entries | Sort-Object Seconds
                                
                                # Regroupement 3min
                                $sections = @()
                                $currentGroup = @()
                                $lastTime = -1
                                
                                foreach ($entry in $entries) {
                                    $diff = $entry.Seconds - $lastTime
                                    
                                    if (($diff -gt 180 -or $currentGroup.Count -ge 80) -and $currentGroup.Count -gt 0) {
                                        $sections += ,@($currentGroup)
                                        $currentGroup = @()
                                    }
                                    
                                    $currentGroup += $entry
                                    $lastTime = $entry.Seconds
                                }
                                
                                if ($currentGroup.Count -gt 0) {
                                    $sections += ,@($currentGroup)
                                }
                                
                                $themes = @{
                                    '🎬 Introduction' = @('bienvenue', 'découvrir', 'présenter', 'vidéo', 'aujourd''hui')
                                    '🔧 Outils' = @('outil', 'installer', 'cherry', 'exif', 'setup')
                                    '🔍 Reconnaissance' = @('nmap', 'scan', 'nikto', 'réseau', 'port')
                                    '🎭 Données cachées' = @('métadonnées', 'stage', 'stéganographie', 'cacher')
                                    '🔐 Sécurité Web' = @('web', 'sql', 'injection', 'burp', 'vulnérabilité')
                                    '📡 Analyse réseau' = @('wireshark', 'paquet', 'trafic', 'capture')
                                    '🔑 Exploitation' = @('john', 'crack', 'metasploit', 'exploit', 'hash')
                                    '✅ Conclusion' = @('fin', 'résumé', 'important', 'merci')
                                }
                                
                                $organized = @()
                                foreach ($section in $sections) {
                                    $fullText = ($section | ForEach-Object { $_.Text }) -join ' '
                                    
                                    $words = $fullText -split '\s+'
                                    $unique = @()
                                    $last = ""
                                    foreach ($w in $words) {
                                        if ($w -ne $last -and $w.Length -gt 2) { $unique += $w }
                                        $last = $w
                                    }
                                    $cleanText = $unique -join ' '
                                    # Supprimer les répétitions de phrases (2-3 mots consécutifs)
                                    # Exemple : "bien sûr utiliser bien sûr utiliser" → "bien sûr utiliser"
                                    $iterations = 0
                                    $maxIterations = 5  # Limite pour éviter boucle infinie

                                    while ($iterations -lt $maxIterations) {
                                        $beforeClean = $cleanText

                                        # Pattern 1 : 2 mots répétés (ex: "bien sûr bien sûr")
                                        $cleanText = $cleanText -replace '(\b\w+\s+\w+)\s+\1\b', '$1'

                                        # Pattern 2 : 3 mots répétés (ex: "utiliser les sous-volumes utiliser les sous-volumes")
                                        $cleanText = $cleanText -replace '(\b\w+\s+\w+\s+\w+)\s+\1\b', '$1'

                                        # Pattern 3 : Phrase complète répétée (5+ mots)
                                        $cleanText = $cleanText -replace '(\b(?:\w+\s+){4,}\w+)\s+\1\b', '$1'

                                        # Si aucun changement, on arrête
                                        if ($beforeClean -eq $cleanText) {
                                            break
                                        }

                                        $iterations++
                                    }

                                    # Nettoyer les espaces multiples résiduels
                                    $cleanText = $cleanText -replace '\s{2,}', ' '
                                    $cleanText = $cleanText.Trim()
                                    $theme = "📍 Section"
                                    $maxScore = 0
                                    foreach ($t in $themes.Keys) {
                                        $score = 0
                                        foreach ($kw in $themes[$t]) {
                                            if ($cleanText -match [regex]::Escape($kw)) { $score++ }
                                        }
                                        if ($score -gt $maxScore) {
                                            $maxScore = $score
                                            $theme = $t
                                        }
                                    }
                                    
                                    $organized += [PSCustomObject]@{
                                        Theme = $theme
                                        Start = $section[0].Time
                                        End = $section[-1].Time
                                        Duration = $section[-1].Seconds - $section[0].Seconds
                                        Text = $cleanText
                                    }
                                }
                                
                                $output = "`n`n📖 VERSION COMPACTE (RÉORGANISÉE)`n"
                                $output += "═══════════════════════════════════════════════════════════════`n`n"
                                
                                $num = 1
                                foreach ($s in $organized) {
                                    $m = [math]::Floor($s.Duration / 60)
                                    $sec = [math]::Round($s.Duration % 60)
                                    
                                    $output += "╔═══════════════════════════════════════════════════════════════╗`n"
                                    $output += "║ $($s.Theme) - PARTIE $num/$($organized.Count)`n"
                                    $output += "╚═══════════════════════════════════════════════════════════════╝`n`n"
                                    $output += "⏱️  [$($s.Start) → $($s.End)] (${m}m ${sec}s)`n`n"
                                    $output += "───────────────────────────────────────────────────────────────`n`n"
                                    
                                    $text = $s.Text
                                    while ($text.Length -gt 0) {
                                        $len = [Math]::Min(400, $text.Length)
                                        if ($text.Length -le $len) {
                                            $output += "$text`n`n"
                                            break
                                        }
                                        
                                        $cut = $text.Substring(0, $len).LastIndexOf(' ')
                                        if ($cut -eq -1) { $cut = $len }
                                        
                                        $output += $text.Substring(0, $cut).Trim() + "`n`n"
                                        $text = $text.Substring($cut).TrimStart()
                                    }
                                    
                                    $num++
                                }
                                
                                $totalM = [math]::Floor($entries[-1].Seconds / 60)
                                $totalS = [math]::Round($entries[-1].Seconds % 60)
                                
                                $output += "`n═══════════════════════════════════════════════════════════════`n"
                                $output += "📊 STATISTIQUES`n"
                                $output += "═══════════════════════════════════════════════════════════════`n"
                                $output += "• Durée : ${totalM}m ${totalS}s`n"
                                $output += "• Sections : $($organized.Count) (compression $([math]::Round($entries.Count / $organized.Count, 1))x)`n"
                                
                                ($beforeSource + $output) | Out-File -FilePath $compactFile -Encoding UTF8
                                
                                Write-Host "✅ Version compacte : $($organized.Count) sections" -ForegroundColor Green
                            } else {
                                Write-Host "⚠️  Pas de timestamps à réorganiser" -ForegroundColor Yellow
                            }
                            
                        } catch {
                            Write-Host "⚠️  Réorganisation échouée" -ForegroundColor Yellow
                        }
                        
                        # Ouvrir résumé
                        Write-Host "`n📄 Ouvrir le résumé ? (O/N)" -ForegroundColor Yellow
                        $openSummary = Read-Host
                        
                        if ($openSummary -eq 'O' -or $openSummary -eq 'o') {
                            Write-Host "`n📋 Quelle version ?" -ForegroundColor Cyan
                            Write-Host "  [1] 📄 Détaillée (timestamps bruts)" -ForegroundColor White
                            Write-Host "  [2] 📖 Compacte (thèmes)" -ForegroundColor White
                            
                            $versionChoice = Read-Host "`nChoix (1-2)"
                            
                            if ($versionChoice -eq '2' -and (Test-Path $compactFile)) {
                                notepad $compactFile
                            } else {
                                notepad $summaryFile
                            }
                        }
                        
                        $subFiles | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
                        
                    } catch {
                        Write-Host "`n❌ Erreur Ollama : $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "💡 Assure-toi que:" -ForegroundColor Yellow
                        Write-Host "   1. Ollama est lancé : ollama serve" -ForegroundColor Yellow
                        Write-Host "   2. Llama2 est téléchargé : ollama list" -ForegroundColor Yellow
                    }
                }
            }
            '4' { 
                Write-Host "⚠️  Téléchargement de playlist..." -ForegroundColor Yellow
                yt-dlp -f "best[height<=1080][ext=mp4]/best" --yes-playlist -o "$outputFolder\%(playlist_title)s\%(title)s.%(ext)s" $url
            }
            default {
                Write-Host "❌ Option invalide" -ForegroundColor Red
                Read-Host "Appuie sur Entrée"
                return
            }
        }
        
        Write-Host "`n✅ Téléchargement terminé !" -ForegroundColor Green
        Write-Host "📂 Emplacement : $outputFolder" -ForegroundColor Cyan
        
        Write-Host "`n📂 Ouvrir le dossier ? (O/N)" -ForegroundColor Yellow
        $open = Read-Host
        
        if ($open -eq 'O' -or $open -eq 'o') {
            explorer $outputFolder
        }
        
    } catch {
        Write-Host "`n❌ Erreur lors du téléchargement" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Gray
        Write-Host "`n💡 Vérifie que l'URL est correcte" -ForegroundColor Yellow
    }
    
    Read-Host "`nAppuie sur Entrée pour retourner au menu"
}
