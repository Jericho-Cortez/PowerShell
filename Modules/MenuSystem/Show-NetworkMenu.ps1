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
	Write-Host "  [6] 🔐 Audit de sécurité" -ForegroundColor White
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
	    '6' {
                . "$NetworkPath\Start-SecurityAudit.ps1"
                Start-SecurityAudit
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
