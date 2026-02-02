# 🚀 PowerShell Menu System — Lord Cortez

Toolkit PowerShell modulaire pour lancer des scripts d’administration **Windows** (réseau, sécurité, outils) via un menu interactif.

## 🎯 Objectif
Centraliser mes scripts d’admin dans une structure claire :
- Un point d’entrée : `Start-Menu.ps1`
- Des modules par domaine : `Modules/Network`, `Modules/Tools`, `Modules/School`
- Un système de menus : `Modules/MenuSystem`

## ✨ Contenu principal

### 🖧 Network
Scripts réseau / diagnostic / sécurité :
- `Get-NetworkInfo.ps1`
- `Start-NetworkDiagnostic.ps1`
- `Test-PortScan.ps1`
- `Test-SpeedTest.ps1`
- `Start-SecurityAudit.ps1`
- `Connect-RachelWiFi.ps1`

### 🧰 Tools
Outils d’automatisation (productivité / contenu / utilitaires) :
- `Search-Files.ps1`
- `Sort-Downloads.ps1`
- `MarpConverter.ps1`
- `Get-YouTubeVideo.ps1`
- `Convert-VideoToArticle.ps1`
- `Export-ArticleMediumHTML.ps1`
- `Start-PhoneMirror.ps1`
- `New-QRCodeCustom.ps1` (s’appuie sur `Code/qrcodegenerator.py`)

### 🎓 School
- `Start-SchoolMode.ps1`

## 📁 Structure
```
PowerShell/
├── Install-Prerequisites.ps1
├── README.md
├── Start-Menu.ps1
├── Code/
│   └── qrcodegenerator.py
├── Config/
└── Modules/
    ├── MenuSystem/
    │   ├── Show-MainMenu.ps1
    │   ├── Show-NetworkMenu.ps1
    │   └── Show-ToolsMenu.ps1
    ├── Network/
    │   ├── Connect-RachelWiFi.ps1
    │   ├── Get-NetworkInfo.ps1
    │   ├── Start-NetworkDiagnostic.ps1
    │   ├── Start-SecurityAudit.ps1
    │   ├── Test-PortScan.ps1
    │   └── Test-SpeedTest.ps1
    ├── School/
    │   └── Start-SchoolMode.ps1
    └── Tools/
        ├── Convert-VideoToArticle.ps1
        ├── Export-ArticleMediumHTML.ps1
        ├── Get-YouTubeVideo.ps1
        ├── MarpConverter.ps1
        ├── New-QRCodeCustom.ps1
        ├── Search-Files.ps1
        ├── Sort-Downloads.ps1
        └── Start-PhoneMirror.ps1
```

## ⚙️ Prérequis
- PowerShell 7 recommandé.
- Droits d’exécution des scripts (ExecutionPolicy) à adapter selon ton poste.

## 🚀 Installation & lancement
```powershell
git clone https://github.com/Jericho-Cortez/PowerShell.git
cd .\PowerShell\
.\Install-Prerequisites.ps1
.\Start-Menu.ps1
```

## ➕ Ajouter une nouvelle fonction
1. Crée un fichier dans `Modules\Tools\Ma-Fonction.ps1` (ou `Modules\Network\...`)
2. Ajoute l’entrée dans le menu correspondant :
   - `Modules\MenuSystem\Show-ToolsMenu.ps1`
   - `Modules\MenuSystem\Show-NetworkMenu.ps1`
3. Relance `.\Start-Menu.ps1`

## 🧼 Maintenance
- 1 script = 1 fonctionnalité.
- Nommage PowerShell : Verbe-Nom, fonctions indépendantes et testables.

## 🗺️ Roadmap
- [ ] Logs (CSV/JSON) des actions lancées depuis le menu.
- [ ] Mode non-interactif (paramètres CLI).
- [ ] Tests qualité (PSScriptAnalyzer) via GitHub Actions.
