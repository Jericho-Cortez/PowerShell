function Show-ToolsMenu {
    $ToolsPath = "$PSScriptRoot\..\..\Modules\Tools"
    
    while ($true) {
        Clear-Host
        
        Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║            🛠️  OUTILS                 ║" -ForegroundColor Yellow
        Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  [1] 📱 Générer un QR Code" -ForegroundColor White
        Write-Host "  [2] 🔍 Rechercher un fichier" -ForegroundColor White
        Write-Host "  [3] 📱 Afficher mon téléphone" -ForegroundColor White
        Write-Host "  [4] 🗂️  Trier Downloads" -ForegroundColor White
        Write-Host "  [5] 📥 Télécharger YouTube" -ForegroundColor White
        Write-Host "  [6] 📥 .Md → PDF ou PPTX (Slides)" -ForegroundColor White
        Write-Host "  [7] 🎬 Vidéo YouTube → Article Markdown" -ForegroundColor Cyan
        Write-Host "  [8] 🎨 Markdown → HTML Style Medium" -ForegroundColor Magenta
        Write-Host "  [0] ⬅️  Retour au menu principal" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "Ton choix"
        
        switch ($choice) {
            '1' {
                . "$ToolsPath\New-QRCodeCustom.ps1"
                New-QRCodeCustom
            }
            '2' {
                . "$ToolsPath\Search-Files.ps1"
                Search-Files
            }
            '3' {
                . "$ToolsPath\Start-PhoneMirror.ps1"
                Start-PhoneMirror
            }
            '4' {
                . "$ToolsPath\Sort-Downloads.ps1"
                Sort-Downloads
            }
            '5' {
                . "$ToolsPath\Get-YouTubeVideo.ps1"
                Get-YouTubeVideo
            }
            '6' {
                . "$ToolsPath\Marp_converter.ps1"
                Start-MarpInteractive
            }
            '7' {
                . "$ToolsPath\Convert-VideoToArticle.ps1"
                
                Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║  🎬 CONVERTIR VIDÉO YOUTUBE → ARTICLE MARKDOWN           ║" -ForegroundColor Cyan
                Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                
                $videoUrl = Read-Host "🔗 URL vidéo YouTube (webinaire, conf, tutoriel)"
                
                if ([string]::IsNullOrWhiteSpace($videoUrl)) {
                    Write-Host "`n❌ URL invalide" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                } else {
                    Write-Host "`n🤖 Choisir modèle Ollama (GTX 1060 4GB) :" -ForegroundColor Yellow
                    Write-Host "  [1] qwen2.5:3b - Rapide et léger (recommandé)" -ForegroundColor Green
                    Write-Host "  [2] qwen2.5:7b - Meilleur qualité (plus lent)" -ForegroundColor White
                    Write-Host "  [3] phi3:mini - Ultra rapide" -ForegroundColor Gray
                    
                    $modelChoice = Read-Host "`nChoix (1-3, défaut=1)"
                    
                    $selectedModel = switch ($modelChoice) {
                        "2" { "qwen2.5:7b-instruct-q4_K_M" }
                        "3" { "phi3:mini-4k-instruct-q4_K_M" }
                        default { "qwen2.5:3b-instruct-q4_K_M" }
                    }
                    
                    Write-Host "`n🎙️  Modèle Whisper (si pas de sous-titres) :" -ForegroundColor Yellow
                    Write-Host "  [1] base - Équilibré (recommandé)" -ForegroundColor Green
                    Write-Host "  [2] tiny - Très rapide" -ForegroundColor Gray
                    Write-Host "  [3] small - Meilleur précision" -ForegroundColor White
                    
                    $whisperChoice = Read-Host "`nChoix (1-3, défaut=1)"
                    
                    $selectedWhisper = switch ($whisperChoice) {
                        "2" { "tiny" }
                        "3" { "small" }
                        default { "base" }
                    }
                    
                    Convert-VideoToArticle -Url $videoUrl -Model $selectedModel -WhisperModel $selectedWhisper
                }
                
                Write-Host ""
                Read-Host "Appuie sur Entrée pour continuer"
            }
            '8' {
                # ✅ FIX : Charger avec Import-Module pour éviter erreurs execution policy
                try {
                    Import-Module "$ToolsPath\Export-ArticleMediumHTML.ps1" -Force -ErrorAction Stop
                } catch {
                    Write-Host "`n❌ Erreur chargement module : $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "`n🔧 Fix rapide :" -ForegroundColor Yellow
                    Write-Host "   Unblock-File -Path `"$ToolsPath\Export-ArticleMediumHTML.ps1`"" -ForegroundColor Cyan
                    Read-Host "`nAppuie sur Entrée"
                    continue
                }

                Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
                Write-Host "║  🎨 EXPORT MARKDOWN → HTML STYLE MEDIUM                   ║" -ForegroundColor Magenta
                Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
                Write-Host ""

                # ✅ FIX : Lister les fichiers .md disponibles
                $articlesPath = "$env:USERPROFILE\Videos\YouTube\Articles"

                if (Test-Path $articlesPath) {
                    $fichiersMD = Get-ChildItem -Path $articlesPath -Filter "*.md" | 
                                  Sort-Object LastWriteTime -Descending |
                                  Select-Object -First 10

                    if ($fichiersMD.Count -gt 0) {
                        Write-Host "📂 Fichiers .md récents trouvés :`n" -ForegroundColor Cyan

                        for ($i = 0; $i -lt $fichiersMD.Count; $i++) {
                            $taille = [math]::Round($fichiersMD[$i].Length / 1KB, 1)
                            Write-Host "  [$($i+1)] $($fichiersMD[$i].Name) ($taille KB)" -ForegroundColor Gray
                        }

                        Write-Host "`n  [0] Autre fichier (chemin manuel)" -ForegroundColor Yellow
                        Write-Host ""

                        $fileChoice = Read-Host "📄 Choix du fichier (0-$($fichiersMD.Count))"

                        if ($fileChoice -match '^\d+$' -and [int]$fileChoice -gt 0 -and [int]$fileChoice -le $fichiersMD.Count) {
                            $fichierMD = $fichiersMD[[int]$fileChoice - 1].FullName
                        } elseif ($fileChoice -eq "0") {
                            $fichierMD = Read-Host "`n📄 Chemin complet du fichier .md"
                        } else {
                            Write-Host "`n❌ Choix invalide" -ForegroundColor Red
                            Start-Sleep -Seconds 2
                            continue
                        }
                    } else {
                        Write-Host "⚠️  Aucun fichier .md trouvé dans $articlesPath" -ForegroundColor Yellow
                        $fichierMD = Read-Host "`n📄 Chemin complet du fichier .md"
                    }
                } else {
                    $fichierMD = Read-Host "📄 Chemin complet du fichier .md"
                }

                # Vérifier si c'est juste un nom (sans chemin)
                if (-not [System.IO.Path]::IsPathRooted($fichierMD)) {
                    $fichierMD = Join-Path $articlesPath $fichierMD
                }

                # Vérifier existence
                if (-not (Test-Path $fichierMD)) {
                    Write-Host "`n❌ Fichier introuvable : $fichierMD" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                } else {
                    # Options d'export
                    Write-Host "`n🎨 Options d'export :" -ForegroundColor Yellow
                    Write-Host "  [1] Light mode (blanc)" -ForegroundColor White
                    Write-Host "  [2] Dark mode (noir)" -ForegroundColor Gray

                    $themeChoice = Read-Host "`nChoix (1-2, défaut=1)"
                    $useDarkMode = ($themeChoice -eq "2")

                    Write-Host "`n📑 Table des matières ?" -ForegroundColor Yellow
                    Write-Host "  [1] Oui" -ForegroundColor Green
                    Write-Host "  [2] Non" -ForegroundColor Gray

                    $tocChoice = Read-Host "`nChoix (1-2, défaut=1)"
                    $useTOC = ($tocChoice -ne "2")

                    Write-Host "`n🌐 Ouvrir dans le navigateur après export ?" -ForegroundColor Yellow
                    Write-Host "  [1] Oui" -ForegroundColor Green
                    Write-Host "  [2] Non" -ForegroundColor Gray

                    $browserChoice = Read-Host "`nChoix (1-2, défaut=1)"
                    $openBrowser = ($browserChoice -ne "2")

                    # Exécuter conversion
                    try {
                        Export-ArticleMediumHTML -FichierMarkdown $fichierMD `
                            -DarkMode:$useDarkMode `
                            -AvecTableMatieres:$useTOC `
                            -OuvrirNavigateur:$openBrowser
                    } catch {
                        Write-Host "`n❌ Erreur conversion : $($_.Exception.Message)" -ForegroundColor Red
                    }
                }

                Write-Host ""
                Read-Host "Appuie sur Entrée pour continuer"
            }
            '0' {
                return
            }
            default {
                Write-Host "`n❌ Choix invalide" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}
