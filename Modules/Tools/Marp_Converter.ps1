# ========================================================================
# CONVERTISSEUR OBSIDIAN → SLIDES (Marp_converter.ps1)
# Version 3.0 : Conversion individuelle OU fusion en 1 PPTX
# ========================================================================

function Marp_converter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DossierSource,

        [Parameter(Mandatory = $false)]
        [ValidateSet("pdf", "pptx", "html")]
        [string]$FormatSortie = "pptx"
    )

    Write-Host "`nCONVERTISSEUR OBSIDIAN → SLIDES" -ForegroundColor Cyan
    Write-Host "Dossier source : $DossierSource" -ForegroundColor Gray
    Write-Host "Format sortie : $($FormatSortie.ToUpper())" -ForegroundColor Gray

    if (-not (Test-Path -Path $DossierSource -PathType Container)) {
        Write-Host "`nERREUR: Le dossier n'existe pas." -ForegroundColor Red
        return
    }

    # Verifier Marp
    Write-Host "`nVerification de Marp CLI..." -ForegroundColor Yellow
    try {
        $null = marp --version 2>$null
        Write-Host "OK Marp CLI trouve" -ForegroundColor Green
    }
    catch {
        Write-Host "ERREUR: Marp CLI non installe." -ForegroundColor Red
        Write-Host "Installation : npm install -g @marp-team/marp-cli" -ForegroundColor Cyan
        return
    }

    $fichiersMD = @(Get-ChildItem -Path $DossierSource -Filter "*.md" -Recurse | Sort-Object FullName)
    
    if ($fichiersMD.Count -eq 0) {
        Write-Host "Aucun fichier .md trouve." -ForegroundColor Yellow
        return
    }

    Write-Host "Trouves : $($fichiersMD.Count) fichier(s)" -ForegroundColor Green

    $stats = @{ Total = $fichiersMD.Count; Reussis = 0; Images = 0 }

    foreach ($fichier in $fichiersMD) {
        Write-Host "`n$('=' * 70)" -ForegroundColor Magenta
        Write-Host "Fichier: $($fichier.Name)" -ForegroundColor Cyan

        # Creer dossier temp
        $dossierTemp = Join-Path -Path $env:TEMP -ChildPath "marp_temp_$(Get-Random)"
        New-Item -ItemType Directory -Path $dossierTemp -Force | Out-Null
        Write-Host "   Dossier temp : $dossierTemp" -ForegroundColor Gray

        # DETECTION AMELIOREE DU DOSSIER IMAGES
        Write-Host "   Recherche des images..." -ForegroundColor Gray
        
        $imagesFiles = @()
        
        # 1. Chercher dans le meme dossier que le .md
        $imagesFiles += Get-ChildItem -Path $fichier.DirectoryName -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension -match '\.(png|jpg|jpeg|gif|svg|webp)$'
        }
        
        # 2. Chercher recursivement dans les sous-dossiers
        $imagesFiles += Get-ChildItem -Path $fichier.DirectoryName -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension -match '\.(png|jpg|jpeg|gif|svg|webp)$'
        }
        
        # 3. Dédupliquer
        $imagesFiles = $imagesFiles | Sort-Object FullName -Unique
        
        # Copier images
        $compteurImages = 0
        if ($imagesFiles) {
            Write-Host "   Trouve : $($imagesFiles.Count) image(s)" -ForegroundColor Green
            
            foreach ($img in $imagesFiles) {
                Copy-Item -Path $img.FullName -Destination $dossierTemp -Force -ErrorAction SilentlyContinue
                $compteurImages++
            }
            Write-Host "   OK $compteurImages image(s) copiees" -ForegroundColor Green
            
            $stats.Images += $compteurImages
        } else {
            Write-Host "   Aucune image trouvee" -ForegroundColor Yellow
        }

        # CONVERSION AVEC RETOURS A LA LIGNE ET CHEMINS ABSOLUS
        $contenu = Get-Content -Path $fichier.FullName -Raw -Encoding UTF8
        
        # Convertir le chemin en format URL (slashes forward)
        $dossierTempURL = $dossierTemp -replace '\\', '/'
        $contenu = $contenu -replace '!\[\[([^\]]+\.(png|jpg|jpeg|gif|svg|webp))\]\]', "`n`n![]($dossierTempURL/$1)`n`n"
        
        # Sauvegarder sans BOM (requis par Marp pour parser le frontmatter)
        $fichierTempMD = Join-Path -Path $dossierTemp -ChildPath "$($fichier.BaseName).md"
        [System.IO.File]::WriteAllText($fichierTempMD, $contenu, [System.Text.UTF8Encoding]::new($false))

        # Fichier de sortie
        $fichierSortie = Join-Path -Path $fichier.DirectoryName -ChildPath "$($fichier.BaseName).$FormatSortie"

        Write-Host "`nConversion en $($FormatSortie.ToUpper())..." -ForegroundColor Yellow

        try {
            # Verifier que le fichier temp existe bien
            if (-not (Test-Path $fichierTempMD)) {
                Write-Host "ERREUR: Fichier temp introuvable : $fichierTempMD" -ForegroundColor Red
                continue
            }

            # Appel Marp direct (sans tableau pour eviter les problemes de passage d'args)
            $marpOutput = switch ($FormatSortie) {
                "pdf"  { & marp $fichierTempMD -o $fichierSortie --pdf  --allow-local-files --no-config 2>&1 }
                "pptx" { & marp $fichierTempMD -o $fichierSortie --pptx --allow-local-files --no-config 2>&1 }
                "html" { & marp $fichierTempMD -o $fichierSortie --html --allow-local-files --no-config 2>&1 }
            }

            $marpErrors = $marpOutput | Where-Object { $_ -match '\[  ERR\]' }
            if ($marpErrors) {
                $marpErrors | ForEach-Object { Write-Host "   [MARP] $_" -ForegroundColor Red }
            }

            if (Test-Path -Path $fichierSortie) {
                $tailleKB = [math]::Round((Get-Item $fichierSortie).Length / 1KB, 2)
                
                if ($tailleKB -gt 5) {
                    Write-Host "OK SUCCES ! ($tailleKB KB)" -ForegroundColor Green
                    Write-Host "   $fichierSortie" -ForegroundColor Gray
                    $stats.Reussis++
                } else {
                    Write-Host "WARNING: Fichier suspect ($tailleKB KB) - verifiez le contenu" -ForegroundColor Yellow
                }
            } else {
                Write-Host "ERREUR: Echec de generation" -ForegroundColor Red
                $marpOutput | ForEach-Object { Write-Host "   [MARP] $_" -ForegroundColor DarkRed }
            }
        }
        catch {
            Write-Host "ERREUR: $_" -ForegroundColor Red
        }
        finally {
            # Nettoyer
            if (Test-Path $dossierTemp) {
                Remove-Item $dossierTemp -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host "`n$('=' * 70)" -ForegroundColor Magenta
    Write-Host "RESUME : $($stats.Reussis)/$($stats.Total) fichiers" -ForegroundColor Cyan
    Write-Host "   $($stats.Images) image(s) traitee(s)" -ForegroundColor Gray
    Write-Host "Termine !`n" -ForegroundColor Green
}

# ========================================================================

function Merge-MarpFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DossierSource,
        
        [Parameter(Mandatory = $false)]
        [string]$NomFichierFinal = "Presentation_Fusionnee"
    )

    Write-Host "`nFUSION OBSIDIAN → 1 PPTX" -ForegroundColor Cyan
    Write-Host "Dossier source : $DossierSource" -ForegroundColor Gray
    Write-Host "Resultat : $NomFichierFinal.pptx" -ForegroundColor Gray

    if (-not (Test-Path -Path $DossierSource -PathType Container)) {
        Write-Host "`nERREUR: Le dossier n'existe pas." -ForegroundColor Red
        return
    }

    # Verifier Marp
    Write-Host "`nVerification de Marp CLI..." -ForegroundColor Yellow
    try {
        $null = marp --version 2>$null
        Write-Host "OK Marp CLI trouve" -ForegroundColor Green
    }
    catch {
        Write-Host "ERREUR: Marp CLI non installe." -ForegroundColor Red
        return
    }

    # Trouver tous les fichiers .md
    $fichiersMD = @(Get-ChildItem -Path $DossierSource -Filter "*.md" -Recurse | Sort-Object FullName)
    
    if ($fichiersMD.Count -eq 0) {
        Write-Host "Aucun fichier .md trouve." -ForegroundColor Yellow
        return
    }

    Write-Host "Trouves : $($fichiersMD.Count) fichier(s)" -ForegroundColor Green

    # Creer dossier temp
    $dossierTemp = Join-Path -Path $env:TEMP -ChildPath "marp_merge_$(Get-Random)"
    New-Item -ItemType Directory -Path $dossierTemp -Force | Out-Null
    Write-Host "   Dossier temp : $dossierTemp" -ForegroundColor Gray

    # ETAPE 1 : Copier TOUTES les images dans le temp
    Write-Host "`nEtape 1 : Copie des images..." -ForegroundColor Yellow
    $totalImages = 0
    
    # Recherche GLOBALE de toutes les images dans le dossier source ET tous les sous-dossiers
    $toutesLesImages = Get-ChildItem -Path $DossierSource -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -match '\.(png|jpg|jpeg|gif|svg|webp)$'
    }
    
    Write-Host "   Recherche globale : $(($toutesLesImages | Measure-Object).Count) fichier(s) image(s)" -ForegroundColor Gray
    
    # Copier toutes les images uniques
    $imagesCopiees = @()
    if ($toutesLesImages) {
        foreach ($img in $toutesLesImages) {
            # Verifier qu'on ne copie pas deux fois le meme fichier
            if ($imagesCopiees -notcontains $img.Name) {
                Copy-Item -Path $img.FullName -Destination $dossierTemp -Force -ErrorAction SilentlyContinue
                $imagesCopiees += $img.Name
                $totalImages++
            }
        }
    }
    
    Write-Host "   Copie effectuee : $totalImages image(s)" -ForegroundColor Green
    
    foreach ($fichier in $fichiersMD) {
        Write-Host "   OK $($fichier.BaseName)" -ForegroundColor Green
    }
    
    Write-Host "   Total : $totalImages image(s)" -ForegroundColor Green

    # ETAPE 2 : Fusionner tous les .md en UN SEUL
    Write-Host "`nEtape 2 : Fusion des fichiers .md..." -ForegroundColor Yellow
    
    # Convertir le chemin temp en format URL pour les chemins d'images
    $dossierTempURL = $dossierTemp -replace '\\', '/'
    
    $contenuFusionne = ""
    
    foreach ($fichier in $fichiersMD) {
        $contenu = Get-Content -Path $fichier.FullName -Raw -Encoding UTF8
        
        # DEBUG: Afficher les images trouvees
        $imagesDetectees = [regex]::Matches($contenu, '!\[\[([^\]]+\.(png|jpg|jpeg|gif|svg|webp))\]\]')
        if ($imagesDetectees.Count -gt 0) {
            Write-Host "   DEBUG $($fichier.BaseName) : $($imagesDetectees.Count) image(s) detectee(s)" -ForegroundColor Cyan
            foreach ($img in $imagesDetectees) {
                $nomImg = $img.Groups[1].Value
                Write-Host "      - $nomImg" -ForegroundColor DarkCyan
            }
        }
        
        # Convertir ![[nom.ext]] en ![](chemin/absolu/nom.ext) avec chemin complet vers dossier temp
        $contenu = $contenu -replace '!\[\[([^\]]+\.(png|jpg|jpeg|gif|svg|webp))\]\]', "![]($dossierTempURL/`$1)"
        
        # Ajouter un titre pour le fichier + separateur
        $titre = $fichier.BaseName
        $contenuFusionne += "---`n`n"
        $contenuFusionne += "# $titre`n`n"
        $contenuFusionne += $contenu
        $contenuFusionne += "`n`n"
    }
    
    Write-Host "   OK Fusion completee" -ForegroundColor Green
    
    # ETAPE 2b : Nettoyer les references aux images cassees
    Write-Host "   Nettoyage des images manquantes..." -ForegroundColor Yellow
    
    # Trouver toutes les references aux images dans le markdown fusionne
    $imgMatches = [regex]::Matches($contenuFusionne, '!\[\]\(([^\)]+)\)')
    $compteurNettoyage = 0
    
    foreach ($match in $imgMatches) {
        $nomImg = $match.Groups[1].Value
        # Extraire le nom du fichier (au cas ou le chemin soit present)
        $nomFichier = Split-Path -Leaf $nomImg
        
        # Verifier si le fichier existe dans le dossier temp
        if (-not (Test-Path "$dossierTemp\$nomFichier")) {
            # Fichier n'existe pas, supprimer la reference
            $contenuFusionne = $contenuFusionne -replace [regex]::Escape($match.Value), ""
            $compteurNettoyage++
        }
    }
    
    if ($compteurNettoyage -gt 0) {
        Write-Host "   Supprime : $compteurNettoyage reference(s) cassee(s)" -ForegroundColor Green
    }

    # ETAPE 3 : Sauvegarder le fichier fusionne
    $fichierMDFusionne = Join-Path -Path $dossierTemp -ChildPath "Presentation_Fusionnee.md"
    [System.IO.File]::WriteAllText($fichierMDFusionne, $contenuFusionne, [System.Text.UTF8Encoding]::new($false))

    # ETAPE 4 : Convertir en PPTX
    Write-Host "`nEtape 3 : Conversion en PPTX..." -ForegroundColor Yellow
    
    # CHEMIN COMPLET OBLIGATOIRE
    $fichierSortie = Join-Path -Path $DossierSource -ChildPath "$NomFichierFinal.pptx"
    
    Write-Host "   Chemin de sortie : $fichierSortie" -ForegroundColor Gray
    
    Write-Host "   Lancement Marp..." -ForegroundColor Gray
    & marp $fichierMDFusionne -o $fichierSortie --pptx --allow-local-files --no-config 2>&1 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }

    Write-Host "   Verification du fichier cree..." -ForegroundColor Gray
    Start-Sleep -Seconds 1

    # RESULTAT FINAL AVEC VERIFICATION
    if (Test-Path -Path $fichierSortie) {
        $tailleMB = [math]::Round((Get-Item $fichierSortie).Length / 1MB, 2)
        $tailleKB = [math]::Round((Get-Item $fichierSortie).Length / 1KB, 2)
        
        Write-Host "`n$('=' * 70)" -ForegroundColor Magenta
        Write-Host "OK SUCCES TOTAL !" -ForegroundColor Green
        Write-Host "`nRESUME :" -ForegroundColor Cyan
        Write-Host "   - Fichiers fusionnes : $($fichiersMD.Count)" -ForegroundColor Gray
        Write-Host "   - Images integrees : $totalImages" -ForegroundColor Gray
        Write-Host "   - Taille PPTX : $tailleMB MB ($tailleKB KB)" -ForegroundColor Gray
        
        Write-Host "`nFICHIER CREE ICI :" -ForegroundColor Cyan
        Write-Host "   $fichierSortie" -ForegroundColor Yellow
        Write-Host "`nOuverture du dossier..." -ForegroundColor Green
        
        # Ouvrir l'explorateur au bon endroit
        explorer "/select,`"$fichierSortie`""
        
        Write-Host "   (Dossier ouvert dans l'Explorateur)" -ForegroundColor Green
        Write-Host ""
        
    } else {
        Write-Host "`nERREUR : Fichier NON cree !" -ForegroundColor Red
        Write-Host "   Chemin attendu : $fichierSortie" -ForegroundColor Yellow
        Write-Host "   Verifiez :" -ForegroundColor Gray
        Write-Host "   - Que Pandoc fonctionne correctement" -ForegroundColor Gray
        Write-Host "   - L'espace disque disponible" -ForegroundColor Gray
        Write-Host "   - Les permissions en ecriture" -ForegroundColor Gray
        Write-Host ""
    }

    # Nettoyer
    if (Test-Path $dossierTemp) {
        Write-Host "Nettoyage du dossier temp..." -ForegroundColor Gray
        Remove-Item $dossierTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ========================================================================

function Show-MarpHelp {
    Clear-Host
    Write-Host "`nCONVERTISSEUR OBSIDIAN → SLIDES (Marp CLI)" -ForegroundColor Cyan
    Write-Host "`n- Convertit ![[image]] -> ![](image)" -ForegroundColor Gray
    Write-Host "- Genere PPTX/PDF/HTML avec images integrees" -ForegroundColor Gray
    Write-Host "- Detection auto des dossiers d'images" -ForegroundColor Gray
    Write-Host "- Fusion de plusieurs fichiers en 1 PPTX`n" -ForegroundColor Gray
    Write-Host "Installation : npm install -g @marp-team/marp-cli`n" -ForegroundColor Cyan
}

function Start-MarpInteractive {
    Show-MarpHelp
    
    Write-Host "Chemin du dossier :" -ForegroundColor Cyan
    $chemin = Read-Host "  "
    $chemin = $chemin.Trim('"').Trim("'")
    
    if ([string]::IsNullOrWhiteSpace($chemin)) { $chemin = Get-Location }
    
    if (-not (Test-Path $chemin)) {
        Write-Host "`nERREUR: Dossier introuvable`n" -ForegroundColor Red
        Pause
        return
    }
    
    Write-Host "`nChoix du mode :" -ForegroundColor Cyan
    Write-Host "   [1] Convertir individuellement (1 PPTX par fichier)" -ForegroundColor Gray
    Write-Host "   [2] Fusionner tous les fichiers (1 PPTX unique)" -ForegroundColor Gray
    $choixMode = Read-Host "  Choix"
    
    if ($choixMode -eq "2") {
        Write-Host "`nNom du fichier final (defaut: Presentation_Fusionnee) :" -ForegroundColor Cyan
        $nomFinal = Read-Host "  "
        if ([string]::IsNullOrWhiteSpace($nomFinal)) { $nomFinal = "Presentation_Fusionnee" }
        
        Merge-MarpFiles -DossierSource $chemin -NomFichierFinal $nomFinal
        
        # PAUSE APRES LA FUSION
        Write-Host ""
        Write-Host "Appuie sur Entree pour retourner au menu..." -ForegroundColor Yellow
        $null = Read-Host
        
    } else {
        Write-Host "`nFormat : [1] PPTX  [2] HTML  [3] PDF" -ForegroundColor Cyan
        $choix = Read-Host "  Choix"
        
        $format = switch ($choix) {
            "2" { "html" }
            "3" { "pdf" }
            default { "pptx" }
        }
        
        Marp_converter -DossierSource $chemin -FormatSortie $format
        
        # PAUSE APRES LA CONVERSION
        Write-Host ""
        Write-Host "Appuie sur Entree pour retourner au menu..." -ForegroundColor Yellow
        $null = Read-Host
    }
}
