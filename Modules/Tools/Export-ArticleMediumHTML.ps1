# ═══════════════════════════════════════════════════════════════════════════════
# 🎨 EXPORT MARKDOWN → HTML STYLE MEDIUM
# Version 1.0 : Conversion article Markdown en HTML professionnel
# ═══════════════════════════════════════════════════════════════════════════════

function Export-ArticleMediumHTML {
    <#
    .SYNOPSIS
    Convertit un fichier Markdown en HTML au style Medium (design professionnel)

    .DESCRIPTION
    Transforme un article Markdown en HTML standalone avec :
    - Design professionnel style Medium (typo Georgia, espacement parfait)
    - Syntax highlighting pour le code (Highlight.js)
    - Responsive (mobile-friendly)
    - Dark mode optionnel
    - Table des matières cliquable (optionnelle)

    .PARAMETER FichierMarkdown
    Chemin vers le fichier .md à convertir

    .PARAMETER DarkMode
    Active le thème sombre (optionnel)

    .PARAMETER AvecTableMatieres
    Génère une table des matières automatique

    .PARAMETER OuvrirNavigateur
    Ouvre automatiquement le HTML dans le navigateur par défaut

    .EXAMPLE
    Export-ArticleMediumHTML -FichierMarkdown "C:\Articles\mon_article.md"

    .EXAMPLE
    Export-ArticleMediumHTML -FichierMarkdown "article.md" -DarkMode -AvecTableMatieres -OuvrirNavigateur
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FichierMarkdown,

        [Parameter(Mandatory=$false)]
        [switch]$DarkMode,

        [Parameter(Mandatory=$false)]
        [switch]$AvecTableMatieres,

        [Parameter(Mandatory=$false)]
        [switch]$OuvrirNavigateur
    )

    Write-Host "`n🎨 ========== EXPORT HTML STYLE MEDIUM ==========" -ForegroundColor Cyan

    # Vérifier fichier source
    if (-not (Test-Path $FichierMarkdown)) {
        Write-Host "❌ Fichier introuvable : $FichierMarkdown" -ForegroundColor Red
        return
    }

    $fichier = Get-Item $FichierMarkdown
    Write-Host "📄 Source : $($fichier.Name)" -ForegroundColor Gray

    # Vérifier Pandoc
    Write-Host "🔍 Vérification Pandoc..." -ForegroundColor Yellow
    try {
        $null = pandoc --version 2>$null
        Write-Host "✅ Pandoc trouvé" -ForegroundColor Green
    } catch {
        Write-Host "❌ Pandoc non installé !" -ForegroundColor Red
        Write-Host "💡 Installation : winget install --id JohnMacFarlane.Pandoc" -ForegroundColor Cyan
        return
    }

    # Lire contenu Markdown
    Write-Host "📖 Lecture du contenu..." -ForegroundColor Yellow
    $contenuMD = Get-Content -Path $FichierMarkdown -Raw -Encoding UTF8

    # Extraire métadonnées
    $titre = "Article Technique"
    $auteur = $env:USERNAME
    $date = Get-Date -Format "dd MMMM yyyy"

    if ($contenuMD -match '^#\s+(.+)') {
        $titre = $matches[1]
    }

    # Fichier HTML de sortie
    $fichierHTML = Join-Path $fichier.DirectoryName "$($fichier.BaseName).html"

    Write-Host "🎨 Génération HTML style Medium..." -ForegroundColor Yellow

    # Convertir Markdown → HTML avec Pandoc
    $tempMD = Join-Path $env:TEMP "temp_article_$(Get-Random).md"
    $contenuMD | Out-File -FilePath $tempMD -Encoding UTF8

    $pandocArgs = @(
        $tempMD,
        "-f", "markdown",
        "-t", "html",
        "--standalone",
        "--highlight-style=github-dark"
    )

    if ($AvecTableMatieres) {
        $pandocArgs += "--toc"
        $pandocArgs += "--toc-depth=3"
    }

    $htmlContent = & pandoc $pandocArgs 2>$null

    # ✅ NOUVEAU : Vérifier que HTML n'est pas vide
    if ([string]::IsNullOrWhiteSpace($htmlContent)) {
        Write-Host "❌ Pandoc a retourné un HTML vide !" -ForegroundColor Red
        Write-Host "💡 Causes possibles :" -ForegroundColor Yellow
        Write-Host "   - Syntaxe Markdown invalide" -ForegroundColor Gray
        Write-Host "   - Caractères spéciaux non supportés" -ForegroundColor Gray
        Write-Host "   - Encodage du fichier incorrect" -ForegroundColor Gray

        Write-Host "`n🔄 Nouvelle tentative avec options permissives..." -ForegroundColor Cyan
        # Tenter re-conversion avec options plus permissives
        $pandocArgs = @(

            "-f", "markdown+smart",
            $tempMD,
            "--standalone",
            "-t", "html5",
            "--quiet"
            "--metadata", "charset=UTF-8",

        )
        $htmlContent = & pandoc $pandocArgs 2>$null
        Write-Host "❌ Échec de conversion après 2 tentatives" -ForegroundColor Red
        if ([string]::IsNullOrWhiteSpace($htmlContent)) {
            return
            Remove-Item $tempMD -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "✅ Conversion réussie (tentative 2)" -ForegroundColor Green

    # Générer template HTML
    $templateHTML = Get-MediumHTMLTemplate -Titre $titre -Auteur $auteur -Date $date -DarkMode:$DarkMode -AvecTOC:$AvecTableMatieres

    # Injecter contenu
    $htmlFinal = $templateHTML -replace '<!--CONTENT-->', $bodyContent

    # Sauvegarder avec UTF-8 BOM pour compatibilité maximale
    $utf8WithBOM = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($fichierHTML, $htmlFinal, $utf8WithBOM)

    # Nettoyer temp
    Remove-Item $tempMD -Force -ErrorAction SilentlyContinue

    # Résultat
    $tailleKB = [math]::Round((Get-Item $fichierHTML).Length / 1KB, 2)

    Write-Host "`n✅ HTML généré avec succès !" -ForegroundColor Green
    Write-Host "   📂 Fichier : $fichierHTML" -ForegroundColor Gray
    Write-Host "   📊 Taille : $tailleKB KB" -ForegroundColor Gray

    if ($DarkMode) {
        Write-Host "   🌙 Thème : Dark Mode" -ForegroundColor Magenta
    } else {
        Write-Host "   ☀️  Thème : Light Mode" -ForegroundColor Yellow
    }

    if ($AvecTableMatieres) {
        Write-Host "   📑 Table des matières incluse" -ForegroundColor Cyan
    }

    # Ouvrir dans navigateur
    if ($OuvrirNavigateur) {
        Write-Host "`n🌐 Ouverture dans le navigateur..." -ForegroundColor Cyan
        Start-Process $fichierHTML
    }

    Write-Host "`n✨ Terminé !`n" -ForegroundColor Green

    return $fichierHTML
}

# ═══════════════════════════════════════════════════════════════════════════

function Get-MediumHTMLTemplate {
    param(
        [string]$Titre,
        [string]$Auteur,
        [string]$Date,
        [switch]$DarkMode,
        [switch]$AvecTOC
    )

    # Variables CSS selon thème
    if ($DarkMode) {
        $bgColor = "#0a0a0a"
        $textColor = "#e4e4e4"
        $headingColor = "#ffffff"
        $linkColor = "#1a8fff"
        $codeBlockBg = "#1e1e1e"
        $codeBorder = "#333"
        $quoteBg = "#1a1a1a"
        $quoteBorder = "#444"
        $highlightTheme = "github-dark"
    } else {
        $bgColor = "#ffffff"
        $textColor = "#292929"
        $headingColor = "#000000"
        $linkColor = "#0066cc"
        $codeBlockBg = "#f7f7f7"
        $codeBorder = "#e1e1e1"
        $quoteBg = "#f9f9f9"
        $quoteBorder = "#ddd"
        $highlightTheme = "github"
    }

    $tocSection = if ($AvecTOC) {
        @"
        <nav id="toc" class="table-of-contents">
            <h3>📑 Table des Matières</h3>
        </nav>
"@
    } else { "" }

    return @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="author" content="$Auteur">
    <meta name="description" content="Article technique : $Titre">
    <title>$Titre</title>

    <!-- Highlight.js pour syntax highlighting -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/$highlightTheme.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>

    <style>
        /* ═══ RESET ═══ */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        /* ═══ VARIABLES ═══ */
        :root {
            --bg-color: $bgColor;
            --text-color: $textColor;
            --heading-color: $headingColor;
            --link-color: $linkColor;
            --code-bg: $codeBlockBg;
            --code-border: $codeBorder;
            --quote-bg: $quoteBg;
            --quote-border: $quoteBorder;
        }

        /* ═══ BASE ═══ */
        body {
            font-family: 'Georgia', 'Times New Roman', serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.8;
            font-size: 21px;
            padding: 0;
            margin: 0;
        }

        /* ═══ CONTAINER MEDIUM ═══ */
        .medium-container {
            max-width: 680px;
            margin: 60px auto;
            padding: 0 24px;
        }

        /* ═══ HEADER ═══ */
        header {
            margin-bottom: 48px;
            padding-bottom: 32px;
            border-bottom: 1px solid var(--code-border);
        }

        header h1 {
            font-family: 'Georgia', serif;
            font-size: 42px;
            font-weight: 700;
            color: var(--heading-color);
            line-height: 1.25;
            margin-bottom: 16px;
            letter-spacing: -0.02em;
        }

        .meta {
            display: flex;
            align-items: center;
            gap: 16px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            font-size: 15px;
            color: #6B6B6B;
            margin-top: 24px;
        }

        .meta .author {
            font-weight: 600;
            color: var(--heading-color);
        }

        /* ═══ TABLE DES MATIÈRES ═══ */
        .table-of-contents {
            background: var(--quote-bg);
            border-left: 3px solid var(--link-color);
            padding: 24px;
            margin: 32px 0;
            border-radius: 4px;
        }

        .table-of-contents h3 {
            font-size: 18px;
            margin-bottom: 16px;
            color: var(--heading-color);
        }

        .table-of-contents ul {
            list-style: none;
            padding-left: 0;
        }

        .table-of-contents li {
            margin: 8px 0;
        }

        .table-of-contents a {
            color: var(--text-color);
            text-decoration: none;
            transition: color 0.2s;
        }

        .table-of-contents a:hover {
            color: var(--link-color);
        }

        /* ═══ TYPOGRAPHY ═══ */
        article h2 {
            font-size: 32px;
            font-weight: 700;
            color: var(--heading-color);
            margin: 48px 0 24px 0;
            line-height: 1.3;
            letter-spacing: -0.01em;
        }

        article h3 {
            font-size: 26px;
            font-weight: 600;
            color: var(--heading-color);
            margin: 40px 0 20px 0;
            line-height: 1.4;
        }

        article h4 {
            font-size: 22px;
            font-weight: 600;
            color: var(--heading-color);
            margin: 32px 0 16px 0;
        }

        article p {
            margin: 24px 0;
            line-height: 1.8;
            font-size: 21px;
        }

        article a {
            color: var(--link-color);
            text-decoration: underline;
            transition: opacity 0.2s;
        }

        article a:hover {
            opacity: 0.8;
        }

        /* ═══ LISTES ═══ */
        article ul, article ol {
            margin: 24px 0;
            padding-left: 40px;
        }

        article li {
            margin: 12px 0;
            line-height: 1.7;
        }

        /* ═══ CITATIONS ═══ */
        article blockquote {
            border-left: 4px solid var(--quote-border);
            background: var(--quote-bg);
            padding: 20px 24px;
            margin: 32px 0;
            font-style: italic;
            color: #6B6B6B;
            border-radius: 4px;
        }

        /* ═══ CODE INLINE ═══ */
        article code:not(pre code) {
            background: var(--code-bg);
            border: 1px solid var(--code-border);
            padding: 3px 8px;
            border-radius: 4px;
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            font-size: 17px;
            color: #d73a49;
        }

        /* ═══ CODE BLOCKS ═══ */
        article pre {
            background: var(--code-bg);
            border: 1px solid var(--code-border);
            border-radius: 6px;
            padding: 24px;
            margin: 32px 0;
            overflow-x: auto;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }

        article pre code {
            background: none;
            border: none;
            padding: 0;
            font-size: 16px;
            color: inherit;
            line-height: 1.6;
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
        }

        /* ═══ IMAGES ═══ */
        article img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 40px auto;
            border-radius: 4px;
            box-shadow: 0 4px 16px rgba(0,0,0,0.1);
        }

        /* ═══ TABLES ═══ */
        article table {
            width: 100%;
            border-collapse: collapse;
            margin: 32px 0;
            font-size: 18px;
        }

        article th, article td {
            padding: 12px 16px;
            border: 1px solid var(--code-border);
            text-align: left;
        }

        article th {
            background: var(--code-bg);
            font-weight: 600;
            color: var(--heading-color);
        }

        /* ═══ SEPARATOR ═══ */
        article hr {
            border: none;
            border-top: 1px solid var(--code-border);
            margin: 48px 0;
        }

        /* ═══ FOOTER ═══ */
        footer {
            margin-top: 80px;
            padding-top: 32px;
            border-top: 1px solid var(--code-border);
            text-align: center;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            font-size: 14px;
            color: #6B6B6B;
        }

        /* ═══ RESPONSIVE ═══ */
        @media (max-width: 768px) {
            body {
                font-size: 18px;
            }

            .medium-container {
                padding: 0 16px;
                margin: 32px auto;
            }

            header h1 {
                font-size: 32px;
            }

            article h2 {
                font-size: 26px;
            }

            article h3 {
                font-size: 22px;
            }
        }
    </style>
</head>
<body>
    <div class="medium-container">
        <header>
            <h1>$Titre</h1>
            <div class="meta">
                <span class="author">✍️ $Auteur</span>
                <span>•</span>
                <span>📅 $Date</span>
            </div>
        </header>

        $tocSection

        <article>
            <!--CONTENT-->
        </article>

        <footer>
            <p>📝 Généré automatiquement avec Export-ArticleMediumHTML</p>
            <p>© $(Get-Date -Format yyyy) - Tous droits réservés</p>
        </footer>
    </div>

    <script>
        // Syntax highlighting automatique
        document.addEventListener('DOMContentLoaded', (event) => {
            document.querySelectorAll('pre code').forEach((block) => {
                hljs.highlightElement(block);
            });
        });
    </script>
</body>
</html>
"@
}

# ═══════════════════════════════════════════════════════════════════════════

function Convert-FolderToMediumHTML {
    <#
    .SYNOPSIS
    Convertit TOUS les fichiers .md d'un dossier en HTML style Medium

    .PARAMETER DossierSource
    Chemin vers le dossier contenant les fichiers .md

    .PARAMETER DarkMode
    Active le thème sombre pour tous les fichiers

    .PARAMETER AvecTableMatieres
    Génère table des matières pour tous les fichiers

    .EXAMPLE
    Convert-FolderToMediumHTML -DossierSource "C:\Articles"

    .EXAMPLE
    Convert-FolderToMediumHTML -DossierSource "C:\Articles" -DarkMode -AvecTableMatieres
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DossierSource,

        [Parameter(Mandatory=$false)]
        [switch]$DarkMode,

        [Parameter(Mandatory=$false)]
        [switch]$AvecTableMatieres
    )

    Write-Host "`n🎨 ========== CONVERSION DOSSIER → HTML MEDIUM ==========" -ForegroundColor Cyan

    if (-not (Test-Path $DossierSource)) {
        Write-Host "❌ Dossier introuvable" -ForegroundColor Red
        return
    }

    $fichiersMD = @(Get-ChildItem -Path $DossierSource -Filter "*.md" -Recurse)

    if ($fichiersMD.Count -eq 0) {
        Write-Host "⚠️  Aucun fichier .md trouvé" -ForegroundColor Yellow
        return
    }

    Write-Host "📌 Trouvés : $($fichiersMD.Count) fichier(s)" -ForegroundColor Green

    $stats = @{ Total = $fichiersMD.Count; Réussis = 0 }

    foreach ($fichier in $fichiersMD) {
        Write-Host "`n$('-' * 70)" -ForegroundColor Magenta
        Write-Host "📄 $($fichier.Name)" -ForegroundColor Cyan

        try {
            Export-ArticleMediumHTML -FichierMarkdown $fichier.FullName -DarkMode:$DarkMode -AvecTableMatieres:$AvecTableMatieres
            $stats.Réussis++
        } catch {
            Write-Host "❌ Erreur : $_" -ForegroundColor Red
        }
    }

    Write-Host "`n$(\'=\' * 70)" -ForegroundColor Magenta
    Write-Host "📊 RÉSUMÉ : $($stats.Réussis)/$($stats.Total) convertis" -ForegroundColor Cyan
    Write-Host "✨ Terminé !`n" -ForegroundColor Green
}
