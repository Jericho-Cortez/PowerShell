# ═══════════════════════════════════════════════════════════════════════════════
# 🎬 CONVERTIR N'IMPORTE QUELLE VIDÉO EN ARTICLE BLOG COMPLET
# ═══════════════════════════════════════════════════════════════════════════════

function Convert-VideoToArticle {
    <#
    .SYNOPSIS
    Transforme automatiquement une vidéo YouTube en article blog complet
    
    .DESCRIPTION
    Télécharge l'audio, extrait sous-titres/transcription, génère résumé IA,
    puis crée un article blog structuré avec références et timestamps
    
    .PARAMETER Url
    URL de la vidéo YouTube (webinaire, conf, tutoriel, etc.)
    
    .PARAMETER Model
    Modèle Ollama à utiliser (qwen2.5, llama3.2, phi3, gemma2)
    
    .PARAMETER OutputFormat
    Format de sortie : Markdown, HTML, Medium, Substack
    
    .EXAMPLE
    Convert-VideoToArticle -Url "https://youtube.com/watch?v=abc123"
    
    .EXAMPLE
    Convert-VideoToArticle -Url "https://youtube.com/watch?v=abc123" -Model "qwen2.5:7b" -OutputFormat "Medium"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("qwen2.5:7b-instruct-q4_K_M", "llama3.2:3b-instruct-q4_K_M", "phi3:mini-4k-instruct-q4_K_M", "gemma2:2b-instruct-q4_K_M")]
        [string]$Model = "qwen2.5:7b-instruct-q4_K_M",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Markdown", "HTML", "Medium", "Substack")]
        [string]$OutputFormat = "Markdown"
    )
    
    Write-Host "`n🎬 CONVERSION VIDÉO → ARTICLE BLOG" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    
    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 1 : EXTRACTION MÉTADONNÉES VIDÉO
    # ═══════════════════════════════════════════════════════════
    
    Write-Host "`n📊 Extraction métadonnées..." -ForegroundColor Yellow
    
    try {
        $videoTitle = yt-dlp --get-title $Url 2>$null
        $videoDuration = yt-dlp --get-duration $Url 2>$null
        $videoChannel = yt-dlp --print "%(uploader)s" $Url 2>$null
        $videoDate = yt-dlp --print "%(upload_date)s" $Url 2>$null
        $videoDescription = yt-dlp --print "%(description)s" $Url 2>$null | Select-Object -First 500
        
        Write-Host "✅ Titre : $videoTitle" -ForegroundColor Green
        Write-Host "✅ Chaîne : $videoChannel" -ForegroundColor Green
        Write-Host "✅ Durée : $videoDuration" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Erreur extraction métadonnées : $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    $safeTitle = $videoTitle -replace '[^\w\s-]', '' -replace '\s+', '_'
    $outputFolder = "$env:USERPROFILE\Videos\YouTube\Articles"
    
    if (-not (Test-Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
    }
    
    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 2 : TÉLÉCHARGEMENT AUDIO
    # ═══════════════════════════════════════════════════════════
    
    Write-Host "`n🎵 Téléchargement audio..." -ForegroundColor Yellow
    
    $audioFile = "$outputFolder\$safeTitle.mp3"
    
    if (-not (Test-Path $audioFile)) {
        yt-dlp -x --audio-format mp3 --audio-quality 0 -o $audioFile $Url
        Write-Host "✅ Audio téléchargé" -ForegroundColor Green
    } else {
        Write-Host "✅ Audio déjà existant" -ForegroundColor Gray
    }
    
    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 3 : EXTRACTION TRANSCRIPTION
    # ═══════════════════════════════════════════════════════════
    
    Write-Host "`n📝 Extraction transcription..." -ForegroundColor Yellow
    
    $transcContent = ""
    $timestamps = @()
    
    # Tentative sous-titres YouTube
    yt-dlp --write-auto-sub --sub-lang "en,fr" --skip-download `
        --convert-subs vtt -o "$outputFolder\$safeTitle" $Url 2>$null
    
    Start-Sleep -Seconds 2
    
    $subFiles = @(Get-ChildItem "$outputFolder\$safeTitle*.vtt" -ErrorAction SilentlyContinue)
    
    if ($subFiles.Count -gt 0) {
        Write-Host "✅ Sous-titres YouTube trouvés" -ForegroundColor Green
        
        $rawSubContent = Get-Content $subFiles[0].FullName -Raw -Encoding UTF8
        
        # Parser VTT
        $transcriptLines = @()
        $lines = $rawSubContent -split "`r?`n"
        $currentTimestamp = ""
        
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            
            if ($trimmedLine -match '(\d{2}):(\d{2}):(\d{2})') {
                $currentTimestamp = "$($matches[1]):$($matches[2]):$($matches[3])"
                $timestamps += $currentTimestamp
            }
            elseif ($trimmedLine -and 
                    $trimmedLine -notmatch '^\d+$' -and 
                    $trimmedLine -notmatch '^WEBVTT' -and
                    $trimmedLine -notmatch '^Kind:' -and
                    $trimmedLine -notmatch '^Language:' -and
                    $trimmedLine -notmatch '^NOTE' -and
                    $trimmedLine -notmatch '-->') {
                
                if ($currentTimestamp) {
                    $cleanText = $trimmedLine -replace '<[^>]+>', '' -replace '\s+', ' '
                    $cleanText = $cleanText.Trim()
                    
                    if ($cleanText.Length -gt 5) {
                        $transcriptLines += "[$currentTimestamp] $cleanText"
                    }
                }
            }
        }
        
        # Déduplication
        $cleanedLines = @()
        $lastText = ""
        
        foreach ($tline in $transcriptLines) {
            $textOnly = $tline -replace '^\[.*?\]\s+', ''
            
            $textStart = if ($textOnly.Length -gt 20) { $textOnly.Substring(0, 20) } else { $textOnly }
            $lastStart = if ($lastText.Length -gt 20) { $lastText.Substring(0, 20) } else { $lastText }
            
            if ($textStart -ne $lastStart -and $textOnly.Length -gt 5) {
                $cleanedLines += $tline
                $lastText = $textOnly
            }
        }
        
        $transcContent = $cleanedLines -join "`n"
        
        Write-Host "✅ $($cleanedLines.Count) entrées extraites" -ForegroundColor Green
        
        # Supprimer VTT temporaires
        $subFiles | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
        
    } else {
        Write-Host "⚠️  Pas de sous-titres disponibles, utilisation Whisper..." -ForegroundColor Yellow
        
        # Fallback Whisper
        if (Get-Command whisper -ErrorAction SilentlyContinue) {
            Write-Host "🎤 Transcription Whisper en cours..." -ForegroundColor Cyan
            
            whisper "$audioFile" `
                --model base `
                --language en `
                --output_format vtt `
                --output_dir "$outputFolder" `
                --task transcribe `
                --verbose False
            
            Start-Sleep -Seconds 3
            
            $whisperVttFiles = @(Get-ChildItem "$outputFolder\$safeTitle*.vtt" -ErrorAction SilentlyContinue)
            
            if ($whisperVttFiles.Count -gt 0) {
                $transcContent = Get-Content $whisperVttFiles[0].FullName -Raw -Encoding UTF8
                Write-Host "✅ Transcription Whisper réussie" -ForegroundColor Green
                
                $whisperVttFiles | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
            } else {
                Write-Host "⚠️  Whisper a échoué" -ForegroundColor Yellow
                $transcContent = "Transcription non disponible"
            }
        } else {
            Write-Host "⚠️  Whisper non installé, transcription manuelle nécessaire" -ForegroundColor Yellow
            $transcContent = "Transcription non disponible (installez Whisper : pip install openai-whisper)"
        }
    }
    
    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 4 : GÉNÉRATION ARTICLE AVEC IA
    # ═══════════════════════════════════════════════════════════
    
    Write-Host "`n🧠 Génération article avec $Model..." -ForegroundColor Yellow
    
    # Vérifier Ollama
    try {
        $ollamaCheck = Invoke-WebRequest -Uri "http://localhost:11434/api/version" `
            -ErrorAction Stop -TimeoutSec 5 | ConvertFrom-Json
        Write-Host "✅ Ollama actif (v$($ollamaCheck.version))" -ForegroundColor Green
    } catch {
        Write-Host "❌ Ollama non lancé ! Lance : ollama serve" -ForegroundColor Red
        return
    }
    
    # Vérifier modèle installé
    $installedModels = ollama list 2>$null
    if (-not ($installedModels | Select-String $Model)) {
        Write-Host "📥 Téléchargement $Model..." -ForegroundColor Cyan
        ollama pull $Model
    }
    
    # Limiter taille transcription
    $maxLength = 45000
    
    if ($transcContent.Length -gt $maxLength) {
        Write-Host "⚠️  Transcription longue ($($transcContent.Length) caractères), découpage..." -ForegroundColor Yellow
        
        $cutContent = $transcContent.Substring(0, $maxLength)
        $lastTimestamp = $cutContent.LastIndexOf('[')
        
        if ($lastTimestamp -gt 0) {
            $transcContent = $cutContent.Substring(0, $lastTimestamp).Trim()
            $transcContent += "`n`n[...Transcription tronquée - Consultez la vidéo complète pour plus de détails...]"
        }
    }
    
    # Prompt spécialisé pour article blog technique
    $promptArticle = @"
<start_of_turn>system
You are a technical writer specializing in converting video content into professional blog articles.
You MUST respond in French with a complete, structured tutorial-style article.
<end_of_turn>
<start_of_turn>user
# 🎯 MISSION
Transform this video transcript into a COMPLETE technical blog article (minimum 2000 words).

# 📋 VIDEO METADATA
- **Title**: $videoTitle
- **Channel**: $videoChannel
- **Duration**: $videoDuration
- **URL**: $Url
- **Description**: $videoDescription

# 📖 ARTICLE STRUCTURE (MANDATORY)

## 1. INTRODUCTION (200 words)
- Hook engaging
- Contexte et enjeux
- Pourquoi ce sujet est important
- Ce que le lecteur va apprendre

## 2. TABLE DES MATIÈRES
- Liste des sections principales
- Liens d'ancrage

## 3. PRÉREQUIS
- Connaissances requises
- Outils nécessaires
- Environnement technique

## 4. CONTEXTE ET THÉORIE
- Concepts fondamentaux
- Architecture générale
- Pourquoi ces choix techniques

## 5. GUIDE PRATIQUE ÉTAPE PAR ÉTAPE
Pour chaque étape :
- **Titre clair**
- **Objectif de l'étape**
- **Commandes/code avec explications**
- **Résultat attendu**
- **Troubleshooting potentiel**

Include code blocks with syntax highlighting:
\`\`\`language
code here
\`\`\`

## 6. EXEMPLES CONCRETS ET CAS D'USAGE
- Scénarios réels
- Variations selon contexte
- Bonnes pratiques

## 7. POINTS CLÉS ET PIÈGES À ÉVITER
- ⚠️ Common mistakes
- ✅ Best practices
- 💡 Tips & tricks

## 8. ALLER PLUS LOIN
- Ressources complémentaires
- Documentation officielle
- Communautés et forums

## 9. CONCLUSION
- Résumé des acquis
- Prochaines étapes
- Call to action

## 10. RÉFÉRENCES VIDÉO
- Timestamps importants avec liens directs
- Format : [00:05:23](${Url}&t=323s) - Description

# 📝 TRANSCRIPT
$transcContent

# ⚠️ STRICT REQUIREMENTS
✅ French language ONLY
✅ Minimum 2000 words
✅ Technical accuracy
✅ Code examples with explanations
✅ Markdown formatting
✅ Professional tone
✅ Include video timestamps as references
✅ Add diagrams descriptions (ASCII art acceptable)
❌ NO generic content
❌ NO hallucination
❌ NO copy-paste transcript

Generate the COMPLETE article NOW:
<end_of_turn>
<start_of_turn>model
# $videoTitle

> **Article technique complet** - Tutoriel basé sur le webinaire/conférence  
> *Publié le $(Get-Date -Format "dd MMMM yyyy")* | *Source : $videoChannel*

---

"@
    
    # Appel Ollama
    $ollamaRequest = @{
        model = $Model
        prompt = $promptArticle
        stream = $false
        options = @{
            temperature = 0.3
            top_p = 0.9
            num_predict = 4000
            repeat_penalty = 1.2
            num_ctx = 8192
            num_gpu = 35
            num_thread = 6
        }
    } | ConvertTo-Json -Depth 100
    
    try {
        Write-Host "⏳ Génération en cours (3-10 min selon modèle)..." -ForegroundColor Gray
        
        $response = Invoke-WebRequest -Uri "http://localhost:11434/api/generate" `
            -Method Post `
            -ContentType "application/json; charset=utf-8" `
            -Body $ollamaRequest `
            -TimeoutSec 1800 `
            -ErrorAction Stop
        
        $responseData = $response.Content | ConvertFrom-Json
        $articleContent = $responseData.response
        
        Write-Host "✅ Article généré ($($articleContent.Length) caractères)" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Erreur génération : $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 5 : SAUVEGARDE ARTICLE
    # ═══════════════════════════════════════════════════════════
    
    $articleFile = "$outputFolder\$safeTitle`_ARTICLE.md"
    
    # Ajouter métadonnées en en-tête
    $finalArticle = @"
---
title: "$videoTitle"
author: "Extrait de $videoChannel"
date: $(Get-Date -Format "yyyy-MM-dd")
source: "$Url"
duration: "$videoDuration"
tags: [tutoriel, technique, webinaire]
---

$articleContent

---

## 📚 Références et sources

- 🎥 **Vidéo source** : [$videoTitle]($Url)
- 📺 **Chaîne** : $videoChannel
- ⏱️ **Durée** : $videoDuration
- 📅 **Publié** : $videoDate
- 🔗 **Lien direct** : [Regarder maintenant]($Url)

### Timestamps clés

"@
    
    # Ajouter timestamps importants (tous les 5 minutes)
    if ($timestamps.Count -gt 0) {
        $interval = [Math]::Max(1, [Math]::Floor($timestamps.Count / 10))
        
        for ($i = 0; $i -lt $timestamps.Count; $i += $interval) {
            $ts = $timestamps[$i]
            $seconds = 0
            if ($ts -match '(\d{2}):(\d{2}):(\d{2})') {
                $seconds = [int]$matches[1] * 3600 + [int]$matches[2] * 60 + [int]$matches[3]
            }
            
            $finalArticle += "- [$ts]($Url&t=$($seconds)s) - Point clé $($i+1)`n"
        }
    }
    
    $finalArticle += @"

---

**Article généré automatiquement** le $(Get-Date -Format "dd/MM/yyyy HH:mm")  
**Modèle IA** : $Model  
**Transcription** : $($transcContent.Length) caractères analysés

💡 *Cet article technique est basé sur l'analyse complète de la vidéo source. Pour plus de détails, consultez la vidéo originale.*

"@
    
    $finalArticle | Out-File -FilePath $articleFile -Encoding UTF8
    
    Write-Host "`n✅ Article complet créé !" -ForegroundColor Green
    Write-Host "📄 Fichier : $articleFile" -ForegroundColor Cyan
    
    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 6 : STATISTIQUES ET EXPORT
    # ═══════════════════════════════════════════════════════════
    
    $stats = @{
        "Mots" = ($articleContent -split '\s+').Count
        "Lignes" = ($articleContent -split "`n").Count
        "Sections" = ([regex]::Matches($articleContent, '^##\s+', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
        "Code blocks" = ([regex]::Matches($articleContent, '```')).Count / 2
        "Temps lecture" = [Math]::Ceiling(($articleContent -split '\s+').Count / 200)
    }
    
    Write-Host "`n📊 Statistiques article :" -ForegroundColor Cyan
    foreach ($key in $stats.Keys) {
        Write-Host "  • $key : $($stats[$key])" -ForegroundColor Gray
    }
    
    # Ouvrir dans éditeur
    Write-Host "`n📖 Ouvrir l'article ? (O/N)" -ForegroundColor Yellow
    $openArticle = Read-Host
    
    if ($openArticle -eq 'O' -or $openArticle -eq 'o') {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            code $articleFile
        } else {
            notepad $articleFile
        }
    }
    
    # Export formats alternatifs
    Write-Host "`n📤 Exporter dans d'autres formats ? (O/N)" -ForegroundColor Yellow
    $exportFormats = Read-Host
    
    if ($exportFormats -eq 'O' -or $exportFormats -eq 'o') {
        # HTML
        $htmlFile = $articleFile -replace '\.md$', '.html'
        
        if (Get-Command pandoc -ErrorAction SilentlyContinue) {
            pandoc $articleFile -o $htmlFile --standalone --css=style.css
            Write-Host "✅ Export HTML : $htmlFile" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Pandoc non installé (pour export HTML/PDF)" -ForegroundColor Yellow
            Write-Host "💡 Installation : winget install JohnMacFarlane.Pandoc" -ForegroundColor Cyan
        }
    }
    
    Write-Host "`n🎉 Conversion terminée avec succès !" -ForegroundColor Green
    
    return @{
        ArticleFile = $articleFile
        AudioFile = $audioFile
        VideoTitle = $videoTitle
        Stats = $stats
    }
}

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
    Write-Host "  [3] 🎵 Audio seulement (MP3) + Résumé IA" -ForegroundColor White
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
                Write-Host "`n🤖 Générer un résumé avec IA locale ? (O/N)" -ForegroundColor Yellow
                Write-Host "💡 Ollama Qwen/Llama/Phi3/Gemma - Gratuit et privé" -ForegroundColor Cyan
                $summarize = Read-Host
                
                if ($summarize -eq 'O' -or $summarize -eq 'o') {
                    
                    # ═══════════════════════════════════════════════════════════
                    # 🎯 CHOIX DU MODÈLE (OPTIMISÉ GTX 1650 4GB)
                    # ═══════════════════════════════════════════════════════════
                    
                    Write-Host "`n🤖 Choix du modèle IA (optimisé GTX 1650 4GB) :" -ForegroundColor Cyan
                    Write-Host "  [1] 🏆 qwen2.5:7b-instruct-q4_K_M - Meilleur équilibre (4GB) [RECOMMANDÉ]" -ForegroundColor Green
                    Write-Host "  [2] ⚡ llama3.2:3b-instruct-q4_K_M - Ultra rapide (2GB)" -ForegroundColor White
                    Write-Host "  [3] 🚀 phi3:mini-4k-instruct-q4_K_M - Très rapide (2GB)" -ForegroundColor White
                    Write-Host "  [4] 💡 gemma2:2b-instruct-q4_K_M - Léger et rapide (1.5GB)" -ForegroundColor Yellow
                    
                    $modelChoice = Read-Host "`nChoix (1-4, défaut=1)"
                    
                    $selectedModel = switch ($modelChoice) {
                        "2" { "llama3.2:3b-instruct-q4_K_M" }
                        "3" { "phi3:mini-4k-instruct-q4_K_M" }
                        "4" { "gemma2:2b-instruct-q4_K_M" }
                        default { "qwen2.5:7b-instruct-q4_K_M" }
                    }
                    
                    Write-Host "`n✅ Modèle sélectionné : $selectedModel" -ForegroundColor Cyan
                    Write-Host "💡 Optimisé pour GTX 1650 4GB VRAM" -ForegroundColor Gray
                    
                    # ═══════════════════════════════════════════════════════════
                    # VÉRIFICATION OLLAMA
                    # ═══════════════════════════════════════════════════════════
                    
                    try {
                        $ollamaCheck = Invoke-WebRequest -Uri "http://localhost:11434/api/version" `
                            -ErrorAction Stop -TimeoutSec 5 | ConvertFrom-Json
                        Write-Host "✅ Ollama détecté (v$($ollamaCheck.version))" -ForegroundColor Green
                    } catch {
                        Write-Host "`n❌ Ollama n'est pas lancé !" -ForegroundColor Red
                        Write-Host "💡 Lance : ollama serve" -ForegroundColor Yellow
                        Read-Host "`nAppuie sur Entrée"
                        return
                    }
                    
                    # Vérifier modèle installé
                    $installedModels = ollama list 2>$null
                    if (-not ($installedModels | Select-String $selectedModel)) {
                        Write-Host "`n📥 Téléchargement du modèle $selectedModel..." -ForegroundColor Yellow
                        ollama pull $selectedModel
                    }
                    
                    Write-Host "`n🧠 Génération du résumé avec $selectedModel..." -ForegroundColor Cyan
                    
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
                                # 🔧 FIX : Utiliser 'en' au lieu de 'auto'
                                whisper "$audioFile" --output_format txt --output_dir "$outputFolder" --language en --device cuda 2>&1 | Out-Null
                                
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
                    
                    # ═══════════════════════════════════════════════════════════
                    # 🎨 PROMPT ADAPTÉ AU MODÈLE
                    # ═══════════════════════════════════════════════════════════
                    
                    # Limiter taille pour modèles 4GB
                    $maxLength = 40000
                    
                    if ($transcContent.Length -gt $maxLength) {
                        Write-Host "`n⚠️  Transcription longue ($($transcContent.Length) caractères)" -ForegroundColor Yellow
                        Write-Host "📏 Découpage intelligent..." -ForegroundColor Cyan
                        
                        $cutContent = $transcContent.Substring(0, $maxLength)
                        $lastTimestamp = $cutContent.LastIndexOf('[')
                        
                        if ($lastTimestamp -gt 0) {
                            $transcContent = $cutContent.Substring(0, $lastTimestamp).Trim()
                            $transcContent += "`n`n[...Transcription tronquée pour limite mémoire...]"
                        }
                    }
                    
                    # Prompt optimisé pour Qwen/Llama/Phi3/Gemma
                    $promptGemma = @"
<start_of_turn>system
You MUST respond ONLY in French. NO other language is allowed.
<end_of_turn>
<start_of_turn>user
# 🎯 TÂCHE
Analyser cette transcription YouTube EN FRANÇAIS et créer un résumé structuré.

⚠️ RÈGLE ABSOLUE : Réponds UNIQUEMENT en français.

# 📋 CONTEXTE
- **Titre** : $videoInfo
- **URL** : $url
- **Durée** : $duration

# 📖 FORMAT OBLIGATOIRE

## 📋 RÉSUMÉ EXÉCUTIF
[3-4 phrases max résumant l'essentiel]

## 🎯 CONTEXTE ET ENJEUX
[Qui ? Quoi ? Où ? Quand ? Pourquoi ? De quoi parle cette vidéo ?]

## 📖 DÉROULEMENT CHRONOLOGIQUE
1. **[Événement/Sujet 1]** - Description brève
2. **[Événement/Sujet 2]** - Description brève
[... 5-10 max selon durée]

## 🔑 PERSONNAGES / ACTEURS PRINCIPAUX (si applicable)
- **[Nom 1]** : Rôle
- **[Nom 2]** : Rôle

## 💡 RÉVÉLATIONS / DÉCOUVERTES CLÉS
[Éléments importants, insights, conclusions]

## 🎓 LEÇONS À RETENIR
1. [...]
2. [...]

# 📝 TRANSCRIPTION
$transcContent

# ⚠️ RÈGLES STRICTES
✅ Français uniquement
✅ Factuel uniquement (ne pas inventer)
✅ Conserver timestamps pertinents [HH:MM:SS]
✅ Format Markdown
❌ NE PAS inventer de timestamps s'il n'y en a pas
❌ NE PAS halluciner du contenu

<end_of_turn>
<start_of_turn>model
En français :
"@
                    
                    # Appel Ollama avec paramètres optimisés GTX 1650
                    $ollamaRequest = @{
                        model = $selectedModel
                        prompt = $promptGemma
                        stream = $false
                        options = @{
                            temperature = 0.2
                            top_p = 0.85
                            num_predict = 2000
                            repeat_penalty = 1.3
                            num_ctx = 8192         # Context window adapté
                            num_gpu = 35           # Layers sur GPU (ajusté selon modèle)
                            num_thread = 6         # Threads CPU
                        }
                    } | ConvertTo-Json -Depth 100
                    
                    try {
                        $response = Invoke-WebRequest -Uri "http://localhost:11434/api/generate" `
                            -Method Post `
                            -ContentType "application/json; charset=utf-8" `
                            -Body $ollamaRequest `
                            -TimeoutSec 1200 `
                            -ErrorAction Stop
                        
                        $responseData = $response.Content | ConvertFrom-Json
                        $resumeGenere = $responseData.response
                        
                        # Créer fichier résumé
                        $summaryFile = "$outputFolder\$safeTitle`_RESUME.txt"
                        
                        $finalSummary = @"
═══════════════════════════════════════════════════════════════════════════════
📝 RÉSUMÉ VIDÉO YOUTUBE - $videoInfo
═══════════════════════════════════════════════════════════════════════════════

🔗 URL       : $url
📅 Date      : $(Get-Date -Format "dd/MM/yyyy HH:mm")
🎵 Fichier   : $safeTitle.mp3
🤖 Modèle IA : $selectedModel
⏱️  Durée     : $duration
📊 Timestamps: $($timestamps.Count) entrées

═══════════════════════════════════════════════════════════════════════════════

$resumeGenere

═══════════════════════════════════════════════════════════════════════════════
"@
                        
                        $finalSummary | Out-File -FilePath $summaryFile -Encoding UTF8
                        
                        Write-Host "`n✅ Résumé créé !" -ForegroundColor Green
                        Write-Host "📂 Fichier : $summaryFile" -ForegroundColor Cyan
                        
                        # [... RÉORGANISATION AUTOMATIQUE - INCHANGÉE ...]
                        
                        # Ouvrir résumé
                        Write-Host "`n📄 Ouvrir le résumé ? (O/N)" -ForegroundColor Yellow
                        $openSummary = Read-Host
                        
                        if ($openSummary -eq 'O' -or $openSummary -eq 'o') {
                            notepad $summaryFile
                        }
                        Write-Host "`n📝 Convertir en article blog technique ? (O/N)" -ForegroundColor Yellow
                        Write-Host "💡 Génère un tutoriel complet 2000+ mots avec code et explications" -ForegroundColor Cyan
                        $convertArticle = Read-Host
                        
                        if ($convertArticle -eq 'O' -or $convertArticle -eq 'o') {
                            Write-Host "`n🚀 Lancement conversion article..." -ForegroundColor Cyan
                            Convert-VideoToArticle -Url $url -Model $selectedModel
                        }
                        
                        $subFiles | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
                        
                        $subFiles | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
                        
                    } catch {
                        Write-Host "`n❌ Erreur Ollama : $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "💡 Vérifie que 'ollama serve' est lancé" -ForegroundColor Yellow
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
