#Requires -Version 7.0
<#
.SYNOPSIS
    Installation automatique des prérequis PowerShell Menu System
.DESCRIPTION
    Installe automatiquement tous les outils nécessaires :
    - oh-my-posh + Terminal-Icons
    - Python + modules (qrcode)
    - scrcpy (miroir Android)
    - yt-dlp + ffmpeg
    - Ollama + Llama2 (IA locale)
    - Whisper (transcription)
    - nmap (scan réseau)
.AUTHOR
    Lord Cortez (Jericho)
.VERSION
    1.0.0
#>

# ═══════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════

param(
    [switch]$All,              # Installer tout
    [switch]$Essential,        # Seulement l'essentiel (oh-my-posh, Terminal-Icons)
    [switch]$Python,           # Python + modules
    [switch]$Android,          # scrcpy
    [switch]$YouTube,          # yt-dlp + ffmpeg
    [switch]$AI,               # Ollama + Whisper
    [switch]$Network,          # nmap
    [switch]$SkipChecks        # Ignorer vérifications (forcer install)
)

# ═══════════════════════════════════════════════════════════
# FONCTIONS UTILITAIRES
# ═══════════════════════════════════════════════════════════

function Write-Header {
    param([string]$Text)
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  $Text" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host "`n🔄 $Text..." -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ $Text" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠️  $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "❌ $Text" -ForegroundColor Red
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-ModuleInstalled {
    param([string]$ModuleName)
    return [bool](Get-Module -ListAvailable -Name $ModuleName)
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )
    
    Write-Step "Installation de $DisplayName"
    
    try {
        winget install --id $PackageId --accept-package-agreements --accept-source-agreements --silent
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$DisplayName installé"
            return $true
        } else {
            Write-Warning "$DisplayName : Installation incomplète (code: $LASTEXITCODE)"
            return $false
        }
    } catch {
        Write-Error "Erreur lors de l'installation de $DisplayName"
        Write-Host $_.Exception.Message -ForegroundColor Gray
        return $false
    }
}

# ═══════════════════════════════════════════════════════════
# VÉRIFICATION ENVIRONNEMENT
# ═══════════════════════════════════════════════════════════

Write-Header "INSTALLATION PRÉREQUIS - POWERSHELL MENU SYSTEM"

Write-Host "`n📋 Informations système :" -ForegroundColor Cyan
Write-Host "   • OS        : $([System.Environment]::OSVersion.VersionString)" -ForegroundColor White
Write-Host "   • PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "   • User      : $env:USERNAME" -ForegroundColor White
Write-Host "   • Admin     : $((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" -ForegroundColor White

# Vérifier PowerShell 7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "PowerShell 7+ requis !"
    Write-Host "💡 Installation : winget install Microsoft.PowerShell" -ForegroundColor Cyan
    exit 1
}

# Vérifier winget
if (-not (Test-CommandExists "winget")) {
    Write-Error "winget non disponible !"
    Write-Host "💡 Installe depuis : https://aka.ms/getwinget" -ForegroundColor Cyan
    exit 1
}

Write-Success "Environnement OK"

# ═══════════════════════════════════════════════════════════
# DÉTERMINER LES COMPOSANTS À INSTALLER
# ═══════════════════════════════════════════════════════════

$installEssential = $All -or $Essential
$installPython = $All -or $Python
$installAndroid = $All -or $Android
$installYouTube = $All -or $YouTube
$installAI = $All -or $AI
$installNetwork = $All -or $Network

# Si aucun switch, mode interactif
if (-not ($All -or $Essential -or $Python -or $Android -or $YouTube -or $AI -or $Network)) {
    Write-Host "`n📦 Composants à installer :" -ForegroundColor Yellow
    Write-Host "  [1] ✅ Tout installer (recommandé)" -ForegroundColor White
    Write-Host "  [2] 🎨 Essentiel uniquement (oh-my-posh + Terminal-Icons)" -ForegroundColor White
    Write-Host "  [3] 🎯 Installation personnalisée" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Choix (1-3)"
    
    switch ($choice) {
        '1' {
            $installEssential = $true
            $installPython = $true
            $installAndroid = $true
            $installYouTube = $true
            $installAI = $true
            $installNetwork = $true
        }
        '2' {
            $installEssential = $true
        }
        '3' {
            $installEssential = (Read-Host "Installer oh-my-posh + Terminal-Icons ? (O/N)") -match '^[Oo]'
            $installPython = (Read-Host "Installer Python + modules QR Code ? (O/N)") -match '^[Oo]'
            $installAndroid = (Read-Host "Installer scrcpy (miroir Android) ? (O/N)") -match '^[Oo]'
            $installYouTube = (Read-Host "Installer yt-dlp + ffmpeg ? (O/N)") -match '^[Oo]'
            $installAI = (Read-Host "Installer Ollama + Whisper (IA locale) ? (O/N)") -match '^[Oo]'
            $installNetwork = (Read-Host "Installer nmap (scan réseau) ? (O/N)") -match '^[Oo]'
        }
        default {
            Write-Error "Choix invalide"
            exit 1
        }
    }
}

# Résumé
Write-Host "`n📊 Récapitulatif de l'installation :" -ForegroundColor Magenta
if ($installEssential) { Write-Host "  ✅ oh-my-posh + Terminal-Icons" -ForegroundColor Green }
if ($installPython) { Write-Host "  ✅ Python + qrcode" -ForegroundColor Green }
if ($installAndroid) { Write-Host "  ✅ scrcpy (miroir Android)" -ForegroundColor Green }
if ($installYouTube) { Write-Host "  ✅ yt-dlp + ffmpeg" -ForegroundColor Green }
if ($installAI) { Write-Host "  ✅ Ollama + Whisper" -ForegroundColor Green }
if ($installNetwork) { Write-Host "  ✅ nmap" -ForegroundColor Green }
Write-Host ""

$confirm = Read-Host "Continuer ? (O/N)"
if ($confirm -notmatch '^[Oo]') {
    Write-Warning "Installation annulée"
    exit 0
}

# ═══════════════════════════════════════════════════════════
# INSTALLATION ESSENTIEL
# ═══════════════════════════════════════════════════════════

if ($installEssential) {
    Write-Header "ESSENTIEL : oh-my-posh + Terminal-Icons"
    
    # oh-my-posh
    if (-not $SkipChecks -and (Test-CommandExists "oh-my-posh")) {
        Write-Success "oh-my-posh déjà installé"
    } else {
        Install-WingetPackage -PackageId "JanDeDobbeleer.OhMyPosh" -DisplayName "oh-my-posh"
    }
    
    # Terminal-Icons
    if (-not $SkipChecks -and (Test-ModuleInstalled "Terminal-Icons")) {
        Write-Success "Terminal-Icons déjà installé"
    } else {
        Write-Step "Installation de Terminal-Icons"
        try {
            Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -AllowClobber
            Write-Success "Terminal-Icons installé"
        } catch {
            Write-Error "Erreur Terminal-Icons"
        }
    }
}

# ═══════════════════════════════════════════════════════════
# INSTALLATION PYTHON + MODULES
# ═══════════════════════════════════════════════════════════

if ($installPython) {
    Write-Header "PYTHON + MODULES QR CODE"
    
    # Python
    if (-not $SkipChecks -and (Test-CommandExists "python")) {
        $pythonVersion = python --version 2>&1
        Write-Success "Python déjà installé : $pythonVersion"
    } else {
        Install-WingetPackage -PackageId "Python.Python.3.12" -DisplayName "Python 3.12"
        
        # Rafraîchir PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    
    # pip upgrade
    Write-Step "Mise à jour de pip"
    python -m pip install --upgrade pip --quiet
    
    # qrcode[pil]
    Write-Step "Installation du module qrcode"
    pip install qrcode[pil] --quiet
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Module qrcode installé"
    } else {
        Write-Error "Erreur module qrcode"
    }
    
    # Créer script Python QR Generator
    $pythonScript = "$env:USERPROFILE\Downloads\qrcode_generator.py"
    
    if (-not (Test-Path $pythonScript)) {
        Write-Step "Création du script qrcode_generator.py"
        
        $qrScriptContent = @"
import qrcode
import sys
from datetime import datetime
import os

def generate_qr(text, output_path=None):
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(text)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        if not output_path:
            qr_folder = os.path.join(os.path.expanduser("~"), "OneDrive", "Documents", "QR_Code")
            os.makedirs(qr_folder, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = os.path.join(qr_folder, f"qrcode_{timestamp}.png")
        
        img.save(output_path)
        print(f"SUCCESS:{output_path}")
        
    except Exception as e:
        print(f"ERROR:{str(e)}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("ERROR:Aucun texte fourni")
        sys.exit(1)
    
    text = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    generate_qr(text, output_path)
"@
        
        $qrScriptContent | Out-File -FilePath $pythonScript -Encoding UTF8
        Write-Success "Script créé : $pythonScript"
    } else {
        Write-Success "Script QR déjà présent"
    }
}

# ═══════════════════════════════════════════════════════════
# INSTALLATION SCRCPY (ANDROID)
# ═══════════════════════════════════════════════════════════

if ($installAndroid) {
    Write-Header "SCRCPY - MIROIR ANDROID"
    
    if (-not $SkipChecks -and (Test-CommandExists "scrcpy")) {
        Write-Success "scrcpy déjà installé"
    } else {
        Install-WingetPackage -PackageId "Genymobile.scrcpy" -DisplayName "scrcpy"
    }
}

# ═══════════════════════════════════════════════════════════
# INSTALLATION YT-DLP + FFMPEG
# ═══════════════════════════════════════════════════════════

if ($installYouTube) {
    Write-Header "YT-DLP + FFMPEG"
    
    # yt-dlp
    if (-not $SkipChecks -and (Test-CommandExists "yt-dlp")) {
        Write-Success "yt-dlp déjà installé"
    } else {
        Install-WingetPackage -PackageId "yt-dlp.yt-dlp" -DisplayName "yt-dlp"
    }
    
    # ffmpeg
    if (-not $SkipChecks -and (Test-CommandExists "ffmpeg")) {
        Write-Success "ffmpeg déjà installé"
    } else {
        Install-WingetPackage -PackageId "Gyan.FFmpeg" -DisplayName "ffmpeg"
    }
}

# ═══════════════════════════════════════════════════════════
# INSTALLATION OLLAMA + WHISPER (IA)
# ═══════════════════════════════════════════════════════════

if ($installAI) {
    Write-Header "IA LOCALE - OLLAMA + WHISPER"
    
    # Ollama
    if (-not $SkipChecks -and (Test-CommandExists "ollama")) {
        Write-Success "Ollama déjà installé"
    } else {
        Install-WingetPackage -PackageId "Ollama.Ollama" -DisplayName "Ollama"
        
        # Rafraîchir PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    
    # Télécharger modèle Llama2
    Write-Step "Téléchargement du modèle Llama2 (4.1 GB - 5-10 minutes)"
    Write-Host "💡 Ceci peut prendre du temps selon ta connexion..." -ForegroundColor Cyan
    
    try {
        ollama pull llama2
        Write-Success "Modèle Llama2 téléchargé"
    } catch {
        Write-Warning "Erreur téléchargement Llama2 - Lance manuellement : ollama pull llama2"
    }
    
    # Whisper
    Write-Step "Installation de Whisper (OpenAI)"
    pip install openai-whisper --quiet
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Whisper installé"
    } else {
        Write-Error "Erreur Whisper"
    }
    
    Write-Host "`n💡 Pour utiliser Ollama :" -ForegroundColor Cyan
    Write-Host "   1. Ouvre un terminal et lance : ollama serve" -ForegroundColor White
    Write-Host "   2. Ou redémarre le PC (démarrage automatique)" -ForegroundColor White
}

# ═══════════════════════════════════════════════════════════
# INSTALLATION NMAP
# ═══════════════════════════════════════════════════════════

if ($installNetwork) {
    Write-Header "NMAP - SCANNER RÉSEAU"
    
    if (-not $SkipChecks -and (Test-CommandExists "nmap")) {
        Write-Success "nmap déjà installé"
    } else {
        Install-WingetPackage -PackageId "Insecure.Nmap" -DisplayName "nmap"
    }
}

# ═══════════════════════════════════════════════════════════
# RAFRAÎCHIR ENVIRONNEMENT
# ═══════════════════════════════════════════════════════════

Write-Header "FINALISATION"

Write-Step "Rafraîchissement des variables d'environnement"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# ═══════════════════════════════════════════════════════════
# RAPPORT FINAL
# ═══════════════════════════════════════════════════════════

Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ INSTALLATION TERMINÉE                                  ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📊 Statut des composants :" -ForegroundColor Cyan

$components = @(
    @{Name="oh-my-posh"; Command="oh-my-posh"; Type="Command"},
    @{Name="Terminal-Icons"; Command="Terminal-Icons"; Type="Module"},
    @{Name="Python"; Command="python"; Type="Command"},
    @{Name="qrcode"; Command="pip show qrcode"; Type="PipPackage"},
    @{Name="scrcpy"; Command="scrcpy"; Type="Command"},
    @{Name="yt-dlp"; Command="yt-dlp"; Type="Command"},
    @{Name="ffmpeg"; Command="ffmpeg"; Type="Command"},
    @{Name="Ollama"; Command="ollama"; Type="Command"},
    @{Name="Whisper"; Command="whisper"; Type="Command"},
    @{Name="nmap"; Command="nmap"; Type="Command"}
)

foreach ($comp in $components) {
    $status = switch ($comp.Type) {
        "Command" { Test-CommandExists $comp.Command }
        "Module" { Test-ModuleInstalled $comp.Command }
        "PipPackage" {
            try {
                $null = pip show $comp.Name 2>&1
                $LASTEXITCODE -eq 0
            } catch { $false }
        }
    }
    
    if ($status) {
        Write-Host "  ✅ $($comp.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($comp.Name)" -ForegroundColor Red
    }
}

Write-Host "`n📝 Prochaines étapes :" -ForegroundColor Yellow
Write-Host "  1. Ferme et rouvre PowerShell" -ForegroundColor White
Write-Host "  2. Lance le menu : Start-MenuLoop" -ForegroundColor White

if ($installAI) {
    Write-Host "  3. Pour Ollama : Lance 'ollama serve' dans un terminal" -ForegroundColor White
}

Write-Host "`n💡 Documentation complète :" -ForegroundColor Cyan
Write-Host "   https://github.com/Jericho-Cortez/PowerShell" -ForegroundColor White

Write-Host "`n🎉 Profite bien de ton menu PowerShell !" -ForegroundColor Green

Read-Host "`nAppuie sur Entrée pour quitter"
