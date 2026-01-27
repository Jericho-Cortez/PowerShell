# ═══════════════════════════════════════════════════════════════════════════
# 📊 CONVERTISSEUR OBSIDIAN → SLIDES (Marp_converter.ps1)
# Version 3.0 : Conversion individuelle OU fusion en 1 PPTX
# ═══════════════════════════════════════════════════════════════════════════

function Marp_converter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DossierSource,

        [Parameter(Mandatory = $false)]
        [ValidateSet("pdf", "pptx", "html")]
        [string]$FormatSortie = "pptx"
    )

    Write-Host "`n🎯 ========== CONVERTISSEUR OBSIDIAN → SLIDES ==========" -ForegroundColor Cyan
    Write-Host "📂 Dossier source : $DossierSource" -ForegroundColor Gray
    Write-Host "📊 Format sortie : $($FormatSortie.ToUpper())" -ForegroundColor Gray

    if (-not (Test-Path -Path $DossierSource -PathType Container)) {
        Write-Host "`n❌ Le dossier n'existe pas." -ForegroundColor Red
        return
    }

    # Vérifier Pandoc
    Write-Host "`n🔍 Vérification de Pandoc..." -ForegroundColor Yellow
    try {
        $null = pandoc --version 2>$null
        Write-Host "✅ Pandoc trouvé" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Pandoc non installé." -ForegroundColor Red
        Write-Host "💡 Installation : winget install --id JohnMacFarlane.Pandoc" -ForegroundColor Cyan
        return
    }

    $fichiersMD = @(Get-ChildItem -Path $DossierSource -Filter "*.md" -Recurse | Sort-Object FullName)
    
    if ($fichiersMD.Count -eq 0) {
        Write-Host "⚠️  Aucun fichier .md trouvé." -ForegroundColor Yellow
        return
    }

    Write-Host "📌 Trouvés : $($fichiersMD.Count) fichier(s)" -ForegroundColor Green

    $stats = @{ Total = $fichiersMD.Count; Réussis = 0; Images = 0 }

    foreach ($fichier in $fichiersMD) {
        Write-Host "`n$('=' * 70)" -ForegroundColor Magenta
        Write-Host "📄 $($fichier.Name)" -ForegroundColor Cyan

        # Créer dossier temp
        $dossierTemp = Join-Path -Path $env:TEMP -ChildPath "marp_temp_$(Get-Random)"
        New-Item -ItemType Directory -Path $dossierTemp -Force | Out-Null
        Write-Host "   📦 Dossier temp : $dossierTemp" -ForegroundColor Gray

        # ✅ DÉTECTION AMÉLIORÉE DU DOSSIER IMAGES
        Write-Host "   🔍 Recherche du dossier images..." -ForegroundColor Gray
        
        $dossierImages = $null
        $patterns = @("screen*", "images", "assets", "img", "captures")
        
        foreach ($pattern in $patterns) {
            $trouve = Get-ChildItem -Path $fichier.DirectoryName -Directory -Filter $pattern -ErrorAction SilentlyContinue
            if ($trouve) {
                $dossierImages = $trouve | Select-Object -First 1
                break
            }
        }
        
        # Fallback : chercher manuellement
        if (-not $dossierImages) {
            $dossierImages = Get-ChildItem -Path $fichier.DirectoryName -Directory | Where-Object { 
                $_.Name -match 'screen|image|capture|img|asset' 
            } | Select-Object -First 1
        }

        # Copier images
        $compteurImages = 0
        if ($dossierImages) {
            Write-Host "   📁 Dossier images : $($dossierImages.Name)" -ForegroundColor Green
            
            $imagesFiles = Get-ChildItem -Path $dossierImages.FullName -File | Where-Object {
                $_.Extension -match '\.(png|jpg|jpeg|gif|svg|webp)$'
            }
            
            if ($imagesFiles) {
                foreach ($img in $imagesFiles) {
                    Copy-Item -Path $img.FullName -Destination $dossierTemp -Force
                    $compteurImages++
                }
                Write-Host "   ✅ $compteurImages image(s) copiée(s)" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Aucune image trouvée dans $($dossierImages.Name)" -ForegroundColor Yellow
            }
            
            $stats.Images += $compteurImages
        } else {
            Write-Host "   ⚠️  Aucun dossier d'images trouvé" -ForegroundColor Yellow
        }

        # ✅ CONVERSION AVEC RETOURS À LA LIGNE
        $contenu = Get-Content -Path $fichier.FullName -Raw -Encoding UTF8
        $contenu = $contenu -replace '!\[\[([^\]]+\.(png|jpg|jpeg|gif|svg|webp))\]\]', "`n`n![](`$1)`n`n"
        
        # Sauvegarder
        $fichierTempMD = Join-Path -Path $dossierTemp -ChildPath "$($fichier.BaseName).md"
        $contenu | Out-File -FilePath $fichierTempMD -Encoding UTF8 -NoNewline

        # Fichier de sortie
        $fichierSortie = Join-Path -Path $fichier.DirectoryName -ChildPath "$($fichier.BaseName).$FormatSortie"

        Write-Host "`n🚀 Conversion en $($FormatSortie.ToUpper())..." -ForegroundColor Yellow

        try {
            Push-Location $dossierTemp
            
            $pandocArgs = @(
                "$($fichier.BaseName).md",
                "-o", $fichierSortie,
                "--slide-level=2"
            )
            
            & pandoc $pandocArgs 2>&1 | Out-Null
            
            Pop-Location

            if (Test-Path -Path $fichierSortie) {
                $tailleKB = [math]::Round((Get-Item $fichierSortie).Length / 1KB, 2)
                
                if ($tailleKB -gt 100) {
                    Write-Host "✅ SUCCÈS ! ($tailleKB KB)" -ForegroundColor Green
                    Write-Host "   📂 $fichierSortie" -ForegroundColor Gray
                    $stats.Réussis++
                } else {
                    Write-Host "⚠️  Créé mais sans images ($tailleKB KB)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "❌ Échec de génération" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "❌ Erreur : $_" -ForegroundColor Red
        }
        finally {
            # Nettoyer
            if (Test-Path $dossierTemp) {
                Remove-Item $dossierTemp -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host "`n$('=' * 70)" -ForegroundColor Magenta
    Write-Host "📊 RÉSUMÉ : $($stats.Réussis)/$($stats.Total) fichiers" -ForegroundColor Cyan
    Write-Host "   🖼️  $($stats.Images) image(s) traitée(s)" -ForegroundColor Gray
    Write-Host "✨ Terminé !`n" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════════════════

function Merge-MarpFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DossierSource,
        
        [Parameter(Mandatory = $false)]
        [string]$NomFichierFinal = "Presentation_Fusionnee"
    )

    Write-Host "`n🎯 ========== FUSION OBSIDIAN → 1 PPTX ==========" -ForegroundColor Cyan
    Write-Host "📂 Dossier source : $DossierSource" -ForegroundColor Gray
    Write-Host "📋 Résultat : $NomFichierFinal.pptx" -ForegroundColor Gray

    if (-not (Test-Path -Path $DossierSource -PathType Container)) {
        Write-Host "`n❌ Le dossier n'existe pas." -ForegroundColor Red
        return
    }

    # Vérifier Pandoc
    Write-Host "`n🔍 Vérification de Pandoc..." -ForegroundColor Yellow
    try {
        $null = pandoc --version 2>$null
        Write-Host "✅ Pandoc trouvé" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Pandoc non installé." -ForegroundColor Red
        return
    }

    # Trouver tous les fichiers .md
    $fichiersMD = @(Get-ChildItem -Path $DossierSource -Filter "*.md" -Recurse | Sort-Object FullName)
    
    if ($fichiersMD.Count -eq 0) {
        Write-Host "⚠️  Aucun fichier .md trouvé." -ForegroundColor Yellow
        return
    }

    Write-Host "📌 Trouvés : $($fichiersMD.Count) fichier(s)" -ForegroundColor Green

    # Créer dossier temp
    $dossierTemp = Join-Path -Path $env:TEMP -ChildPath "marp_merge_$(Get-Random)"
    New-Item -ItemType Directory -Path $dossierTemp -Force | Out-Null
    Write-Host "   📦 Dossier temp : $dossierTemp" -ForegroundColor Gray

    # ✅ ÉTAPE 1 : Copier TOUTES les images dans le temp
    Write-Host "`n📸 Étape 1 : Copie des images..." -ForegroundColor Yellow
    $totalImages = 0
    
    foreach ($fichier in $fichiersMD) {
        $cheminDossier = $fichier.DirectoryName
        
        # Chercher dossier images
        $dossierImages = Get-ChildItem -Path $cheminDossier -Directory | Where-Object { 
            $_.Name -match 'screen|image|capture|img|asset' 
        } | Select-Object -First 1
        
        # Copier images
        if ($dossierImages) {
            $imagesFiles = Get-ChildItem -Path $dossierImages.FullName -File | Where-Object {
                $_.Extension -match '\.(png|jpg|jpeg|gif|svg|webp)$'
            }
            
            if ($imagesFiles) {
                foreach ($img in $imagesFiles) {
                    Copy-Item -Path $img.FullName -Destination $dossierTemp -Force
                    $totalImages++
                }
                Write-Host "   ✅ $($fichier.BaseName) : $($imagesFiles.Count) image(s)" -ForegroundColor Green
            }
        }
    }
    
    Write-Host "   📊 Total : $totalImages image(s)" -ForegroundColor Green

    # ✅ ÉTAPE 2 : Fusionner tous les .md en UN SEUL
    Write-Host "`n📋 Étape 2 : Fusion des fichiers .md..." -ForegroundColor Yellow
    
    $contenuFusionné = ""
    
    foreach ($fichier in $fichiersMD) {
        $contenu = Get-Content -Path $fichier.FullName -Raw -Encoding UTF8
        
        # ✅ REGEX CORRECTE
        $contenu = $contenu -replace '!\[\[([^\]]+\.(png|jpg|jpeg|gif|svg|webp))\]\]', "`n`n![](`$1)`n`n"
        
        # Ajouter un titre pour le fichier + séparateur
        $titre = $fichier.BaseName
        $contenuFusionné += "---`n`n"
        $contenuFusionné += "# $titre`n`n"
        $contenuFusionné += $contenu
        $contenuFusionné += "`n`n"
    }
    
    Write-Host "   ✅ Fusion complétée" -ForegroundColor Green

    # ✅ ÉTAPE 3 : Sauvegarder le fichier fusionné
    $fichierMDFusionné = Join-Path -Path $dossierTemp -ChildPath "Presentation_Fusionnee.md"
    $contenuFusionné | Out-File -FilePath $fichierMDFusionné -Encoding UTF8 -NoNewline

    # ✅ ÉTAPE 4 : Convertir en PPTX
    Write-Host "`n🚀 Étape 3 : Conversion en PPTX..." -ForegroundColor Yellow
    
    # 🔴 CHEMIN COMPLET OBLIGATOIRE
    $fichierSortie = Join-Path -Path $DossierSource -ChildPath "$NomFichierFinal.pptx"
    
    Write-Host "   Chemin de sortie : $fichierSortie" -ForegroundColor Gray
    
    Push-Location $dossierTemp
    
    $pandocArgs = @(
        "$fichierMDFusionné",
        "-o", "$fichierSortie",
        "--slide-level=2"
    )
    
    Write-Host "   🔄 Lancement Pandoc..." -ForegroundColor Gray
    & pandoc $pandocArgs 2>&1 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    
    Pop-Location

    Write-Host "   ⏳ Vérification du fichier créé..." -ForegroundColor Gray
    Start-Sleep -Seconds 1

    # ✅ RÉSULTAT FINAL AVEC VÉRIFICATION
    if (Test-Path -Path $fichierSortie) {
        $tailleMB = [math]::Round((Get-Item $fichierSortie).Length / 1MB, 2)
        $tailleKB = [math]::Round((Get-Item $fichierSortie).Length / 1KB, 2)
        
        Write-Host "`n$('=' * 70)" -ForegroundColor Magenta
        Write-Host "✅ SUCCÈS TOTAL !" -ForegroundColor Green
        Write-Host "`n📊 RÉSUMÉ :" -ForegroundColor Cyan
        Write-Host "   • Fichiers fusionnés : $($fichiersMD.Count)" -ForegroundColor Gray
        Write-Host "   • Images intégrées : $totalImages" -ForegroundColor Gray
        Write-Host "   • Taille PPTX : $tailleMB MB ($tailleKB KB)" -ForegroundColor Gray
        
        Write-Host "`n📂 FICHIER CRÉÉ ICI :" -ForegroundColor Cyan
        Write-Host "   $fichierSortie" -ForegroundColor Yellow
        Write-Host "`n✨ Ouverture du dossier..." -ForegroundColor Green
        
        # Ouvrir l'explorateur au bon endroit
        explorer "/select,`"$fichierSortie`""
        
        Write-Host "   (Dossier ouvert dans l'Explorateur)" -ForegroundColor Green
        Write-Host ""
        
    } else {
        Write-Host "`n❌ ERREUR : Fichier NON créé !" -ForegroundColor Red
        Write-Host "   Chemin attendu : $fichierSortie" -ForegroundColor Yellow
        Write-Host "   Vérifiez :" -ForegroundColor Gray
        Write-Host "   • Que Pandoc fonctionne correctement" -ForegroundColor Gray
        Write-Host "   • L'espace disque disponible" -ForegroundColor Gray
        Write-Host "   • Les permissions en écriture" -ForegroundColor Gray
        Write-Host ""
    }

    # Nettoyer
    if (Test-Path $dossierTemp) {
        Write-Host "🧹 Nettoyage du dossier temp..." -ForegroundColor Gray
        Remove-Item $dossierTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ═══════════════════════════════════════════════════════════════════════════

function Show-MarpHelp {
    Clear-Host
    Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      📊 CONVERTISSEUR OBSIDIAN → SLIDES (Pandoc)              ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    Write-Host "✅ Convertit ![[image]] → ![](image) avec retours ligne" -ForegroundColor Gray
    Write-Host "✅ Génère PPTX/PDF/HTML avec images intégrées" -ForegroundColor Gray
    Write-Host "✅ Détection auto des dossiers d'images" -ForegroundColor Gray
    Write-Host "✅ Fusion de plusieurs fichiers en 1 PPTX`n" -ForegroundColor Gray
    Write-Host "💡 Installation : winget install --id JohnMacFarlane.Pandoc`n" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
}

function Start-MarpInteractive {
    Show-MarpHelp
    
    Write-Host "📂 Chemin du dossier :" -ForegroundColor Cyan
    $chemin = Read-Host "  "
    $chemin = $chemin.Trim('"').Trim("'")
    
    if ([string]::IsNullOrWhiteSpace($chemin)) { $chemin = Get-Location }
    
    if (-not (Test-Path $chemin)) {
        Write-Host "`n❌ Dossier introuvable`n" -ForegroundColor Red
        Pause
        return
    }
    
    Write-Host "`n🎯 Choix du mode :" -ForegroundColor Cyan
    Write-Host "   [1] 📊 Convertir individuellement (1 PPTX par fichier)" -ForegroundColor Gray
    Write-Host "   [2] 🔗 Fusionner tous les fichiers (1 PPTX unique)" -ForegroundColor Gray
    $choixMode = Read-Host "  Choix"
    
    if ($choixMode -eq "2") {
        Write-Host "`n📝 Nom du fichier final (défaut: Presentation_Fusionnee) :" -ForegroundColor Cyan
        $nomFinal = Read-Host "  "
        if ([string]::IsNullOrWhiteSpace($nomFinal)) { $nomFinal = "Presentation_Fusionnee" }
        
        Merge-MarpFiles -DossierSource $chemin -NomFichierFinal $nomFinal
        
        # ✅ PAUSE APRÈS LA FUSION
        Write-Host ""
        Write-Host "✨ Appuie sur Entrée pour retourner au menu..." -ForegroundColor Yellow
        $null = Read-Host
        
    } else {
        Write-Host "`n📊 Format : [1] PPTX  [2] HTML  [3] PDF" -ForegroundColor Cyan
        $choix = Read-Host "  Choix"
        
        $format = switch ($choix) {
            "2" { "html" }
            "3" { "pdf" }
            default { "pptx" }
        }
        
        Marp_converter -DossierSource $chemin -FormatSortie $format
        
        # ✅ PAUSE APRÈS LA CONVERSION
        Write-Host ""
        Write-Host "✨ Appuie sur Entrée pour retourner au menu..." -ForegroundColor Yellow
        $null = Read-Host
    }
}
