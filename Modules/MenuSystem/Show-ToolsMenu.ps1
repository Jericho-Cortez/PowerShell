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
