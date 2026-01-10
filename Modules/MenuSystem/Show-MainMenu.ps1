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
