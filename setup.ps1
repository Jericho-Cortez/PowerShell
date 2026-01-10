# ═══════════════════════════════════════════════════════════
# SCRIPT DE CRÉATION DE LA STRUCTURE MODULAIRE
# ═══════════════════════════════════════════════════════════

$BasePath = "C:\Users\jbcde\Documents\Projet\PowerShell"

Write-Host "🔨 Création de la structure modulaire..." -ForegroundColor Cyan
Write-Host "📂 Chemin : $BasePath`n" -ForegroundColor Gray

# Créer les dossiers
$folders = @(
    "Modules\MenuSystem",
    "Modules\Tools",
    "Modules\Network",
    "Modules\School",
    "Config"
)

foreach ($folder in $folders) {
    $path = Join-Path $BasePath $folder
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "✅ Créé : $folder" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Existe déjà : $folder" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ Structure créée avec succès !`n" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# CRÉER LE FICHIER PRINCIPAL Start-Menu.ps1
# ═══════════════════════════════════════════════════════════

$mainMenuContent = @'
# ═══════════════════════════════════════════════════════════
# MENU PRINCIPAL - POINT D'ENTRÉE
# Auteur : Lord Cortez
# ═══════════════════════════════════════════════════════════

$ModulesPath = "$PSScriptRoot\Modules"

# Charger le menu principal
. "$ModulesPath\MenuSystem\Show-MainMenu.ps1"

# Lancer
Show-MainMenu
'@

$mainMenuContent | Out-File "$BasePath\Start-Menu.ps1" -Encoding UTF8
Write-Host "✅ Fichier principal créé : Start-Menu.ps1" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# CRÉER Show-MainMenu.ps1
# ═══════════════════════════════════════════════════════════

$showMainMenuContent = @'
function Show-MainMenu {
    $ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    
    while ($true) {
        Clear-Host
        
        Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        Bienvenue Lord Cortez          ║" -ForegroundColor Cyan
        Write-Host "║       MENU PRINCIPAL - TERMINAL       ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] 🛠️  Outils" -ForegroundColor Yellow
        Write-Host "  [2] 🌐 Réseau" -ForegroundColor Green
        Write-Host "  [3] 🎓 Mode École" -ForegroundColor Cyan
        Write-Host "  [4] 💻 Terminal classique" -ForegroundColor White
        Write-Host "  [0] ❌ Quitter" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host "Ton choix"
        
        switch ($choice) {
            '1' {
                . "$ModulesPath\Modules\MenuSystem\Show-ToolsMenu.ps1"
                Show-ToolsMenu
            }
            '2' {
                . "$ModulesPath\Modules\MenuSystem\Show-NetworkMenu.ps1"
                Show-NetworkMenu
            }
            '3' {
                . "$ModulesPath\Modules\School\Start-SchoolMode.ps1"
                Start-SchoolMode
            }
            '4' {
                Write-Host "`n💻 Terminal classique activé" -ForegroundColor Green
                Write-Host "💡 Tape 'exit' pour revenir au menu`n" -ForegroundColor Gray
                return
            }
            '0' {
                Write-Host "`n👋 À bientôt Lord Cortez !" -ForegroundColor Cyan
                exit
            }
            default {
                Write-Host "`n❌ Choix invalide" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}
'@

$showMainMenuContent | Out-File "$BasePath\Modules\MenuSystem\Show-MainMenu.ps1" -Encoding UTF8
Write-Host "✅ Menu principal créé" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# CRÉER Show-ToolsMenu.ps1
# ═══════════════════════════════════════════════════════════

$showToolsMenuContent = @'
function Show-ToolsMenu {
    $ToolsPath = "$PSScriptRoot\..\..\Modules\Tools"
    
    while ($true) {
        Clear-Host
        
        Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║            🛠️  OUTILS                 ║" -ForegroundColor Yellow
        Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  [1] 📱 Générer un QR Code" -ForegroundColor White
        Write-Host "  [2] 🤖 Ouvrir Perplexity" -ForegroundColor White
        Write-Host "  [3] 🔍 Rechercher un fichier" -ForegroundColor White
        Write-Host "  [4] 📱 Afficher mon téléphone" -ForegroundColor White
        Write-Host "  [5] 🗂️  Trier Downloads" -ForegroundColor White
        Write-Host "  [6] 📥 Télécharger YouTube" -ForegroundColor White
        Write-Host "  [0] ⬅️  Retour au menu principal" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "Ton choix"
        
        switch ($choice) {
            '1' {
                . "$ToolsPath\New-QRCodeCustom.ps1"
                New-QRCodeCustom
            }
            '2' {
                . "$ToolsPath\Open-Perplexity.ps1"
                Open-Perplexity
            }
            '3' {
                . "$ToolsPath\Search-Files.ps1"
                Search-Files
            }
            '4' {
                . "$ToolsPath\Start-PhoneMirror.ps1"
                Start-PhoneMirror
            }
            '5' {
                . "$ToolsPath\Sort-Downloads.ps1"
                Sort-Downloads
            }
            '6' {
                . "$ToolsPath\Get-YouTubeVideo.ps1"
                Get-YouTubeVideo
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
'@

$showToolsMenuContent | Out-File "$BasePath\Modules\MenuSystem\Show-ToolsMenu.ps1" -Encoding UTF8
Write-Host "✅ Menu Outils créé" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# CRÉER Show-NetworkMenu.ps1
# ═══════════════════════════════════════════════════════════

$showNetworkMenuContent = @'
function Show-NetworkMenu {
    $NetworkPath = "$PSScriptRoot\..\..\Modules\Network"
    
    while ($true) {
        Clear-Host
        
        Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║            🌐 RÉSEAU                  ║" -ForegroundColor Green
        Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  [1] 🔐 Se connecter Chez Rachel" -ForegroundColor White
        Write-Host "  [2] 📊 Infos réseau" -ForegroundColor White
        Write-Host "  [3] 🔍 Scan de ports" -ForegroundColor White
        Write-Host "  [4] 🚀 Test de vitesse" -ForegroundColor White
        Write-Host "  [5] 🩺 Diagnostic complet" -ForegroundColor White
        Write-Host "  [0] ⬅️  Retour au menu principal" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "Ton choix"
        
        switch ($choice) {
            '1' {
                . "$NetworkPath\Connect-RachelWiFi.ps1"
                Connect-RachelWiFi
            }
            '2' {
                . "$NetworkPath\Get-NetworkInfo.ps1"
                Get-NetworkInfo
            }
            '3' {
                . "$NetworkPath\Test-PortScan.ps1"
                Test-PortScan
            }
            '4' {
                . "$NetworkPath\Test-SpeedTest.ps1"
                Test-SpeedTest
            }
            '5' {
                . "$NetworkPath\Start-NetworkDiagnostic.ps1"
                Start-NetworkDiagnostic
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
'@

$showNetworkMenuContent | Out-File "$BasePath\Modules\MenuSystem\Show-NetworkMenu.ps1" -Encoding UTF8
Write-Host "✅ Menu Réseau créé" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════
# CRÉER FICHIERS PLACEHOLDER POUR LES FONCTIONS
# ═══════════════════════════════════════════════════════════

$placeholderFunctions = @{
    "Modules\Tools\New-QRCodeCustom.ps1" = "function New-QRCodeCustom { Write-Host 'QR Code - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Tools\Open-Perplexity.ps1" = "function Open-Perplexity { Write-Host 'Perplexity - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Tools\Search-Files.ps1" = "function Search-Files { Write-Host 'Recherche - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Tools\Start-PhoneMirror.ps1" = "function Start-PhoneMirror { Write-Host 'Phone Mirror - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Tools\Sort-Downloads.ps1" = "function Sort-Downloads { Write-Host 'Sort Downloads - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Tools\Get-YouTubeVideo.ps1" = "function Get-YouTubeVideo { Write-Host 'YouTube - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Network\Connect-RachelWiFi.ps1" = "function Connect-RachelWiFi { Write-Host 'WiFi - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Network\Get-NetworkInfo.ps1" = "function Get-NetworkInfo { Write-Host 'Network Info - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Network\Test-PortScan.ps1" = "function Test-PortScan { Write-Host 'Port Scan - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Network\Test-SpeedTest.ps1" = "function Test-SpeedTest { Write-Host 'Speed Test - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\Network\Start-NetworkDiagnostic.ps1" = "function Start-NetworkDiagnostic { Write-Host 'Diagnostic - À implémenter' -ForegroundColor Yellow; Read-Host }"
    "Modules\School\Start-SchoolMode.ps1" = "function Start-SchoolMode { Write-Host 'Mode École - À implémenter' -ForegroundColor Yellow; Read-Host }"
}

Write-Host "`n📝 Création des fichiers de fonctions..." -ForegroundColor Cyan

foreach ($file in $placeholderFunctions.Keys) {
    $filePath = Join-Path $BasePath $file
    $placeholderFunctions[$file] | Out-File $filePath -Encoding UTF8
    Write-Host "✅ $file" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════
# CRÉER README.md
# ═══════════════════════════════════════════════════════════

$readmeContent = @'
# 🚀 PowerShell Menu System - Lord Cortez

Menu interactif modulaire pour administration système et cybersécurité.

## 📁 Structure
PowerShell/
├── Start-Menu.ps1 # Point d'entrée
├── Modules/
│ ├── MenuSystem/ # Menus
│ ├── Tools/ # Outils
│ ├── Network/ # Réseau
│ └── School/ # Mode École
└── Config/ # Configuration

## 🚀 Utilisation

```powershell
cd C:\Users\jbcde\Documents\Projet\PowerShell
.\Start-Menu.ps1
📝 Ajouter une fonction
Crée Modules\Tools\Ma-Fonction.ps1

Ajoute dans Show-ToolsMenu.ps1

C'est tout !

🔧 Maintenance
Chaque fonction est indépendante = facile à modifier/tester.
'@

$readmeContent | Out-File "$BasePath\README.md" -Encoding UTF8
Write-Host "✅ README.md créé" -ForegroundColor Green

Write-Host "n🎉 STRUCTURE COMPLÈTE CRÉÉE !n" -ForegroundColor Green
Write-Host "📂 Chemin : $BasePath" -ForegroundColor Cyan
Write-Host "🚀 Lance avec : .\Start-Menu.ps1`n" -ForegroundColor Yellow