function Connect-RachelWiFi {
    $sshUser = "grizko"
    $sshIP = "54.38.242.167"
    $sshPort = "50000"
    
    Write-Host "`n🔐 Connexion SSH vers ${sshUser}@${sshIP}:${sshPort}..." -ForegroundColor Cyan
    Write-Host "💡 Pour quitter la session SSH, tape 'exit' ou Ctrl+D`n" -ForegroundColor Yellow
    
    ssh -p $sshPort $sshUser@$sshIP
    
    Write-Host "`n✅ Session SSH terminée." -ForegroundColor Green
    Read-Host "Appuie sur Entrée"
}