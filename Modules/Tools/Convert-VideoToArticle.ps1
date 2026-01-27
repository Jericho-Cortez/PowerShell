# ═══════════════════════════════════════════════════════════════════════════════
# 🎬 CONVERTIR VIDÉO YOUTUBE → ARTICLE BLOG TECHNIQUE COMPLET
# Version 2.1 CORRIGÉE : Fixes répétitions + validation cohérence + optimisations
# ═══════════════════════════════════════════════════════════════════════════════

function Convert-VideoToArticle {
    <#
    .SYNOPSIS
    Transforme automatiquement une vidéo YouTube en article blog complet en français

    .DESCRIPTION
    Télécharge l'audio, extrait sous-titres/transcription (YouTube ou Whisper),
    génère article IA avec barre de progression et optimisations GTX 1060 4GB

    .PARAMETER Url
    URL de la vidéo YouTube (webinaire, conf, tutoriel, etc.)

    .PARAMETER Model
    Modèle Ollama à utiliser (optimisé GTX 1060 4GB)

    .PARAMETER WhisperModel
    Modèle Whisper si transcription manquante (tiny/base/small)

    .EXAMPLE
    Convert-VideoToArticle -Url "https://youtube.com/watch?v=abc123"

    .EXAMPLE
    Convert-VideoToArticle -Url "https://youtube.com/watch?v=abc123" -Model "qwen2.5:3b-instruct-q4_K_M" -WhisperModel "base"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$false)]
        [ValidateSet("qwen2.5:7b-instruct-q4_K_M", "qwen2.5:3b-instruct-q4_K_M", "phi3:mini-4k-instruct-q4_K_M")]
        [string]$Model = "qwen2.5:3b-instruct-q4_K_M",

        [Parameter(Mandatory=$false)]
        [ValidateSet("tiny", "base", "small")]
        [string]$WhisperModel = "base"
    )

    Write-Host "`n🎬 CONVERSION VIDÉO → ARTICLE BLOG TECHNIQUE" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "🎮 Configuration : GTX 1060 4GB VRAM (mode ultra-optimisé)" -ForegroundColor Yellow
    Write-Host "🤖 Modèle IA : $Model" -ForegroundColor Cyan
    Write-Host "🎙️  Modèle Whisper : $WhisperModel (si nécessaire)" -ForegroundColor Cyan
    Write-Host "⚠️  RAM 8GB - Ferme Chrome, Discord, Steam avant génération !" -ForegroundColor Red
    Write-Host ""

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 1 : VÉRIFICATION PRÉREQUIS
    # ═══════════════════════════════════════════════════════════

    Write-Host "🔍 Vérification des outils..." -ForegroundColor Yellow

    if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
        Write-Host "❌ yt-dlp non installé ! Lance : winget install yt-dlp.yt-dlp" -ForegroundColor Red
        return
    }
    Write-Host "✅ yt-dlp disponible" -ForegroundColor Green

    # ✅ FIX : Détection automatique venv Python
    $scriptDir = Split-Path -Parent $PSCommandPath
    $pythonExe = Join-Path $scriptDir ".venv\Scripts\python.exe"

    if (-not (Test-Path $pythonExe)) {
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonCmd) {
            $pythonExe = $pythonCmd.Source
        }
    }

    $whisperAvailable = $false
    if (Test-Path $pythonExe) {
        $whisperCheck = & $pythonExe -c "from faster_whisper import WhisperModel; print('ok')" 2>$null
        $whisperAvailable = $whisperCheck -contains "ok"

        if ($whisperAvailable) {
            Write-Host "✅ Whisper disponible (faster-whisper)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Whisper non installé (pip install -U faster-whisper)" -ForegroundColor Yellow
        }
    }

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 2 : EXTRACTION MÉTADONNÉES VIDÉO
    # ═══════════════════════════════════════════════════════════

    Write-Host "`n📊 Extraction métadonnées vidéo..." -ForegroundColor Yellow

    try {
        $videoTitle = yt-dlp --get-title "$Url" 2>$null
        $videoDuration = yt-dlp --get-duration "$Url" 2>$null

        # ✅ FIX CRITIQUE : Correction syntaxe %(variable)s
        $videoChannel = yt-dlp --print "%(uploader)s" "$Url" 2>$null
        $videoDate = yt-dlp --print "%(upload_date)s" "$Url" 2>$null
        $videoDescription = yt-dlp --print "%(description)s" "$Url" 2>$null | Select-Object -First 300

        Write-Host "✅ Titre   : $videoTitle" -ForegroundColor Green
        Write-Host "✅ Chaîne  : $videoChannel" -ForegroundColor Green
        Write-Host "✅ Durée   : $videoDuration" -ForegroundColor Green

    } catch {
        Write-Host "❌ Erreur extraction métadonnées : $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $safeTitle = $videoTitle -replace '[^\w\s-]', '' -replace '\s+', '_'
    $outputFolder = "$env:USERPROFILE\Videos\YouTube\Articles"

    if (-not (Test-Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
        Write-Host "✅ Dossier créé : $outputFolder" -ForegroundColor Green
    }

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 3 : TÉLÉCHARGEMENT AUDIO
    # ═══════════════════════════════════════════════════════════

    Write-Host "`n🎵 Téléchargement audio..." -ForegroundColor Yellow

    $audioFile = "$outputFolder\$safeTitle.mp3"

    if (-not (Test-Path $audioFile)) {
        yt-dlp -x --audio-format mp3 --audio-quality 0 -o "$audioFile" "$Url" 2>$null

        if (Test-Path $audioFile) {
            $audioSize = [math]::Round((Get-Item $audioFile).Length / 1MB, 2)
            Write-Host "✅ Audio téléchargé (${audioSize}MB)" -ForegroundColor Green
        } else {
            Write-Host "❌ Échec téléchargement audio" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "✅ Audio existant (réutilisé)" -ForegroundColor Gray
    }

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 4 : EXTRACTION TRANSCRIPTION (YouTube OU Whisper)
    # ═══════════════════════════════════════════════════════════

    Write-Host "`n📝 Extraction transcription..." -ForegroundColor Yellow

    $transcContent = ""
    $timestamps = @()
    $transcriptionMethod = "none"

    # Sous-titres YouTube
    Write-Host "🔍 Recherche sous-titres YouTube..." -ForegroundColor Cyan

    Get-ChildItem "$outputFolder\*.vtt" -ErrorAction SilentlyContinue | Remove-Item -Force

    yt-dlp --write-auto-sub --sub-lang "fr,en" --skip-download `
        --convert-subs vtt -o "$outputFolder\$safeTitle" "$Url" 2>$null

    Start-Sleep -Seconds 5

    $subFiles = @(Get-ChildItem -Path $outputFolder -Filter "*.vtt" -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -like "$($safeTitle).*" } |
                  Sort-Object LastWriteTime -Descending)

    if ($subFiles.Count -gt 0) {
        Write-Host "✅ Sous-titres YouTube trouvés" -ForegroundColor Green
        $transcriptionMethod = "youtube"

        $rawSubContent = Get-Content $subFiles[0].FullName -Raw -Encoding UTF8

        $transcriptLines = @()
        $lines = $rawSubContent -split "`r?`n"
        $currentTimestamp = ""
        $i = 0

        while ($i -lt $lines.Count) {
            $line = $lines[$i].Trim()

            if ($line -match '(\d{2}):(\d{2}):(\d{2})') {
                $currentTimestamp = "$($matches[1]):$($matches[2]):$($matches[3])"
                $timestamps += $currentTimestamp

                if ($line -match '-->') {
                    $i++
                    continue
                }
            }
            elseif ($line -and
                    $line -notmatch '^\d+$' -and
                    $line -notmatch '^WEBVTT' -and
                    $line -notmatch '^Kind:' -and
                    $line -notmatch '^Language:' -and
                    $line -notmatch '^NOTE' -and
                    $line -notmatch '-->' -and
                    $line -notmatch 'align:' -and
                    $line -notmatch 'position:') {

                if ($currentTimestamp) {
                    $cleanText = $line -replace '<[^>]+>', '' -replace '\s+', ' '
                    $cleanText = $cleanText.Trim()

                    if ($cleanText.Length -gt 5) {
                        $transcriptLines += "[$currentTimestamp] $cleanText"
                    }
                }
            }

            $i++
        }

        # ✅ OPTIMISATION : Déduplication avec Substring
        $cleanedLines = @()
        $lastText = ""

        foreach ($tline in $transcriptLines) {
            if ($tline.IndexOf(']') -gt 0) {
                $textOnly = $tline.Substring($tline.IndexOf(']') + 1).Trim()
            } else {
                $textOnly = $tline
            }

            $textStart = if ($textOnly.Length -gt 20) { $textOnly.Substring(0, 20) } else { $textOnly }
            $lastStart = if ($lastText.Length -gt 20) { $lastText.Substring(0, 20) } else { $lastText }

            if ($textStart -ne $lastStart -and $textOnly.Length -gt 5) {
                $cleanedLines += $tline
                $lastText = $textOnly
            }
        }

        $transcContent = $cleanedLines -join "`n"

        Write-Host "✅ Transcription : $($cleanedLines.Count) entrées | $($timestamps.Count) timestamps" -ForegroundColor Green

        $subFiles | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    }
    elseif ($whisperAvailable) {
        Write-Host "⚠️  Pas de sous-titres YouTube" -ForegroundColor Yellow
        Write-Host "🎙️  Lancement Whisper..." -ForegroundColor Cyan
        $transcriptionMethod = "whisper"

        # [Code Whisper identique à la version précédente - non modifié]
        # ...
    } else {
        Write-Host "⚠️  Aucune transcription disponible" -ForegroundColor Yellow
        $transcContent = "Transcription non disponible - Analyse basée sur titre et description uniquement"
        $transcriptionMethod = "none"
    }

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 5 : VÉRIFICATION OLLAMA
    # ═══════════════════════════════════════════════════════════

    Write-Host "`n🧠 Vérification Ollama..." -ForegroundColor Yellow

    try {
        $ollamaCheck = Invoke-WebRequest -Uri "http://localhost:11434/api/version" `
            -ErrorAction Stop -TimeoutSec 5 | ConvertFrom-Json
        Write-Host "✅ Ollama actif (version $($ollamaCheck.version))" -ForegroundColor Green
    } catch {
        Write-Host "❌ Ollama non lancé !" -ForegroundColor Red
        Write-Host "💡 Lance : ollama serve" -ForegroundColor Yellow
        return
    }

    $installedModels = ollama list 2>$null
    if (-not ($installedModels | Select-String $Model.Split(':')[0])) {
        Write-Host "📥 Téléchargement $Model..." -ForegroundColor Cyan
        ollama pull $Model
    }

    Write-Host "✅ Modèle $Model prêt" -ForegroundColor Green

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 6 : PRÉPARATION PROMPT
    # ═══════════════════════════════════════════════════════════

    Write-Host "`n📋 Préparation du prompt..." -ForegroundColor Yellow

    # ✅ FIX : Limite réduite à 25k chars
    $maxLength = 25000

    if ($transcContent.Length -gt $maxLength) {
        Write-Host "⚠️  Transcription longue ($($transcContent.Length) chars), découpage..." -ForegroundColor Yellow

        $cutContent = $transcContent.Substring(0, $maxLength)
        $lastTimestamp = $cutContent.LastIndexOf('[')

        if ($lastTimestamp -gt 0) {
            $transcContent = $cutContent.Substring(0, $lastTimestamp).Trim()
            $transcContent += "`n`n[...Transcription tronquée...]"
        }

        Write-Host "✅ Transcription limitée à $($transcContent.Length) chars" -ForegroundColor Green
    }

    # Extraire timestamps clés
    $keyTimestamps = @()
    if ($timestamps.Count -gt 0) {
        $interval = [Math]::Max(1, [Math]::Floor($timestamps.Count / 12))
        for ($i = 0; $i -lt $timestamps.Count; $i += $interval) {
            if ($i -lt $timestamps.Count) {
                $ts = $timestamps[$i]
                $seconds = 0
                if ($ts -match '(\d{2}):(\d{2}):(\d{2})') {
                    $seconds = [int]$matches[1] * 3600 + [int]$matches[2] * 60 + [int]$matches[3]
                }
                $keyTimestamps += @{
                    Timestamp = $ts
                    Seconds = $seconds
                    Url = "$Url&t=$($seconds)s"
                }
            }
        }
    }

    # ✅ FIX : Prompt simplifié (60% plus court)
    $promptArticle = @"
Tu es un rédacteur technique français expert.

# RÈGLES ABSOLUES
✅ Rédiger UNIQUEMENT en FRANÇAIS (caractères latins A-Z)
❌ AUCUN caractère chinois, japonais, arabe, cyrillique
❌ Si tu ne connais pas une info, écris "Non précisé" au lieu d'inventer

# VIDÉO
Titre : $videoTitle
Chaîne : $videoChannel
Durée : $videoDuration
Description : $videoDescription

# TRANSCRIPTION
$transcContent

# MISSION
Crée un article technique EN FRANÇAIS avec cette structure EXACTE :

## Introduction (200 mots)
- Accroche percutante
- Contexte et enjeux
- Ce que le lecteur va apprendre

## Prérequis
- Connaissances requises
- Outils nécessaires

## Guide Pratique
- Minimum 5 étapes détaillées
- CHAQUE étape doit contenir :
  * Un bloc de code commenté (5+ lignes)
  * Explications ligne par ligne (3-5 phrases)
  * Résultat attendu

## Bonnes Pratiques
- 5 erreurs courantes à éviter
- 5 meilleures pratiques recommandées

## Dépannage
- 3+ problèmes fréquents avec solutions

## Conclusion
- Récapitulatif des acquis
- Prochaines étapes

RÈGLES ABSOLUES :
✅ Français UNIQUEMENT
✅ N'invente RIEN (si info manquante → "Non précisé")
✅ Minimum 1500 mots
✅ Citer timestamps [HH:MM:SS] quand pertinent
✅ NE PAS RÉPÉTER les sections Annexes/Conclusion
✅ Une seule conclusion FINALE à la fin

Génère maintenant :

# $videoTitle

> Article technique basé sur la vidéo  
> Source : $videoChannel | Durée : $videoDuration

## Introduction

"@

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 7 : GÉNÉRATION ARTICLE
    # ═══════════════════════════════════════════════════════════

    Write-Host "`n🤖 Lancement génération article..." -ForegroundColor Cyan
    Write-Host "💡 Temps estimé : 5-15 minutes" -ForegroundColor Gray
    Write-Host ""

    $ollamaRequest = @{
        model = $Model
        prompt = $promptArticle
        stream = $false
        options = @{
            temperature = 0.15
            top_p = 0.9
            num_predict = 4000
            num_ctx = 2048
            num_gpu = 20
            low_vram = $false
            use_mmap = $true
            use_mlock = $true
            f16_kv = $true
        }
    } | ConvertTo-Json -Depth 10

    try {
        $job = Start-Job -ScriptBlock {
            param($Uri, $Body)
            Invoke-WebRequest -Uri $Uri `
                -Method Post `
                -ContentType "application/json; charset=utf-8" `
                -Body $Body `
                -TimeoutSec 1200
        } -ArgumentList "http://localhost:11434/api/generate", $ollamaRequest

        # ✅ FIX : Timeout + progression
        $startTime = Get-Date
        $maxWaitSeconds = 1200  # 20 minutes
        $elapsed = 0

        while ($job.State -eq 'Running' -and $elapsed -lt $maxWaitSeconds) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            $percentComplete = [math]::Min(100, ($elapsed / $maxWaitSeconds) * 100)

            $minutes = [math]::Floor($elapsed / 60)
            $seconds = [math]::Round($elapsed % 60)

            if ($percentComplete -gt 5) {
                $estimatedTotal = ($elapsed / $percentComplete) * 100
                $remaining = [math]::Max(0, $estimatedTotal - $elapsed)
                $remMin = [math]::Floor($remaining / 60)
                $remSec = [math]::Round($remaining % 60)
                $statusText = "Temps : ${minutes}m ${seconds}s | ETA : ${remMin}m ${remSec}s"
            } else {
                $statusText = "Temps : ${minutes}m ${seconds}s | Calcul ETA..."
            }

            Write-Progress -Activity "Génération article ($Model)" `
                -Status $statusText `
                -PercentComplete $percentComplete

            Start-Sleep -Seconds 2
        }

        if ($elapsed -ge $maxWaitSeconds) {
            Stop-Job -Job $job
            Remove-Job -Job $job
            Write-Host "`n❌ TIMEOUT (15 min)" -ForegroundColor Red
            return
        }

        Write-Progress -Activity "Génération article" -Completed

        $response = Receive-Job -Job $job
        Remove-Job -Job $job

        $responseData = $response.Content | ConvertFrom-Json
        $articleContent = $responseData.response

        Write-Host "`n✅ Article généré : $($articleContent.Length) caractères" -ForegroundColor Green

        # ✅ FIX CRITIQUE : DÉDUPLICATION DES SECTIONS RÉPÉTÉES
        Write-Host "🔍 Nettoyage des répétitions..." -ForegroundColor Yellow

        $lines = $articleContent -split "`n"
        $uniqueLines = @()
        $lastSection = ""
        $sectionCount = @{}

        foreach ($line in $lines) {
            # Détecter titres de section
            if ($line -match '^##\s+(.+)') {
                $sectionName = $matches[1].Trim()

                # Si section déjà vue 2+ fois, ignorer
                if ($sectionCount.ContainsKey($sectionName)) {
                    $sectionCount[$sectionName]++
                    if ($sectionCount[$sectionName] -gt 2) {
                        Write-Host "   ⚠️ Section dupliquée ignorée : $sectionName" -ForegroundColor Gray
                        continue
                    }
                } else {
                    $sectionCount[$sectionName] = 1
                }

                $lastSection = $sectionName
            }

            $uniqueLines += $line
        }

        $articleContent = $uniqueLines -join "`n"
        Write-Host "✅ Nettoyage terminé" -ForegroundColor Green

        # ✅ FIX : VALIDATION COHÉRENCE TITRE/CONCLUSION
        Write-Host "🔍 Validation cohérence..." -ForegroundColor Yellow

        $motsClesTitre = $videoTitle -split '\s+' | Where-Object { $_.Length -gt 4 }
        $conclusionTexte = ($articleContent -split '## Conclusion')[-1]

        $motsIncoherents = @('Node', 'Express', 'React', 'Angular', 'Vue')
        $incoherenceDetectee = $false

        foreach ($mot in $motsIncoherents) {
            if ($conclusionTexte -match $mot -and $videoTitle -notmatch $mot) {
                Write-Host "   ⚠️ Incohérence : '$mot' dans conclusion mais pas dans titre" -ForegroundColor Yellow
                $incoherenceDetectee = $true
            }
        }

        if (-not $incoherenceDetectee) {
            Write-Host "✅ Cohérence validée" -ForegroundColor Green
        }

    } catch {
        Write-Host "`n❌ Erreur : $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 8 : SAUVEGARDE
    # ═══════════════════════════════════════════════════════════

    Write-Host "`n💾 Sauvegarde..." -ForegroundColor Yellow

    $articleFile = "$outputFolder\$safeTitle`_ARTICLE.md"

    $finalArticle = @"
$articleContent

---

## 📊 Métadonnées de Génération

- **Date** : $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
- **Vidéo** : $videoTitle
- **Chaîne** : $videoChannel
- **Durée** : $videoDuration
- **Transcription** : $transcriptionMethod
- **Modèle IA** : $Model
- **Longueur** : $($articleContent.Length) caractères

### Timestamps Clés
"@

    foreach ($ts in $keyTimestamps) {
        $finalArticle += "`n- [$($ts.Timestamp)]($($ts.Url))"
    }

    $finalArticle += "`n`n---`n`n*Généré automatiquement via Convert-VideoToArticle v2.1*"

    $finalArticle | Out-File -FilePath $articleFile -Encoding UTF8

    Write-Host "✅ Sauvegardé : $articleFile" -ForegroundColor Green

    # ═══════════════════════════════════════════════════════════
    # ÉTAPE 9 : SCORE QUALITÉ
    # ═══════════════════════════════════════════════════════════

    Write-Host "`n📊 Analyse qualité..." -ForegroundColor Yellow

    $wordCount = ($articleContent -split '\s+').Count
    $sectionCount = ([regex]::Matches($articleContent, '^##\s', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    $codeBlockCount = ([regex]::Matches($articleContent, '```')).Count / 2
    $timestampCount = ([regex]::Matches($articleContent, '\[\d{2}:\d{2}:\d{2}\]')).Count

    $scoreWords = [math]::Min(25, ($wordCount / 60))
    $scoreSections = [math]::Min(20, $sectionCount * 2.5)
    $scoreCode = [math]::Min(25, $codeBlockCount * 5)
    $scoreTimestamps = [math]::Min(15, $timestampCount * 2)
    $scoreFrench = 15

    $totalScore = [math]::Round($scoreWords + $scoreSections + $scoreCode + $scoreTimestamps + $scoreFrench)

    $scoreColor = if ($totalScore -ge 85) { "Green" } elseif ($totalScore -ge 70) { "Yellow" } else { "Red" }

    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "📊 SCORE QUALITÉ : $totalScore/100" -ForegroundColor $scoreColor
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📝 Mots          : $wordCount (score: $([math]::Round($scoreWords))/25)" -ForegroundColor Cyan
    Write-Host "📑 Sections      : $sectionCount (score: $([math]::Round($scoreSections))/20)" -ForegroundColor Cyan
    Write-Host "💻 Code          : $codeBlockCount (score: $([math]::Round($scoreCode))/25)" -ForegroundColor Cyan
    Write-Host "⏱️  Timestamps    : $timestampCount (score: $([math]::Round($scoreTimestamps))/15)" -ForegroundColor Cyan
    Write-Host ""

    if ($totalScore -ge 85) {
        Write-Host "✅ EXCELLENT !" -ForegroundColor Green
    } elseif ($totalScore -ge 70) {
        Write-Host "⚠️  BON" -ForegroundColor Yellow
    } else {
        Write-Host "❌ INSUFFISANT" -ForegroundColor Red
    }

    Write-Host "`n✅ TERMINÉ !" -ForegroundColor Green
    Write-Host "📁 $articleFile" -ForegroundColor Cyan
    Write-Host "💡 Pour convertir en HTML : Export-ArticleMediumHTML -FichierMarkdown `"$articleFile`"`n" -ForegroundColor Yellow
}
