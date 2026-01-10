function Test-PortScan {
    Write-Host "`n🔍 SCANNER DE PORTS" -ForegroundColor Cyan
    Write-Host "═══════════════════" -ForegroundColor Cyan
    
    $target = Read-Host "`nCible (IP ou hostname)"
    
    Write-Host "`n📋 Type de scan :" -ForegroundColor Yellow
    Write-Host "  [1] Ports communs (16 ports)" -ForegroundColor White
    Write-Host "  [2] Scan complet (1-1024)" -ForegroundColor White
    Write-Host "  [3] Ports personnalisés" -ForegroundColor White
    
    $choice = Read-Host "`nChoix (1-3)"
    
    $ports = switch ($choice) {
        '1' { @(21,22,23,25,53,80,110,143,443,445,3306,3389,5900,8080,8443,9090) }
        '2' { 1..1024 }
        '3' { 
            $custom = Read-Host "Ports (ex: 80,443,8080)"
            $custom -split ',' | ForEach-Object { [int]$_.Trim() }
        }
        default { @(80,443,22,3389) }
    }
    
    Write-Host "`n🔎 Scan de $target en cours..." -ForegroundColor Cyan
    Write-Host "Ports testés : $($ports.Count)" -ForegroundColor Gray
    Write-Host ""
    
    $openPorts = @()
    
    foreach ($port in $ports) {
        Write-Host "." -NoNewline -ForegroundColor Gray
        
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($target, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(100, $false)
        
        if ($wait -and $tcpClient.Connected) {
            $service = switch ($port) {
                21 { "FTP" }
                22 { "SSH" }
                23 { "Telnet" }
                25 { "SMTP" }
                53 { "DNS" }
                80 { "HTTP" }
                110 { "POP3" }
                143 { "IMAP" }
                443 { "HTTPS" }
                445 { "SMB" }
                3306 { "MySQL" }
                3389 { "RDP" }
                5900 { "VNC" }
                8080 { "HTTP-Alt" }
                default { "Inconnu" }
            }
            
            $openPorts += [PSCustomObject]@{
                Port = $port
                Service = $service
                Status = "Ouvert"
            }
        }
        
        $tcpClient.Close()
    }
    
    Write-Host "`n"
    
    if ($openPorts.Count -gt 0) {
        Write-Host "✅ $($openPorts.Count) port(s) ouvert(s) :" -ForegroundColor Green
        Write-Host ""
        Write-Host "╔═══════╦══════════════╦═════════╗" -ForegroundColor Gray
        Write-Host "║ Port  ║ Service      ║ Status  ║" -ForegroundColor Gray
        Write-Host "╠═══════╬══════════════╬═════════╣" -ForegroundColor Gray
        
        foreach ($p in $openPorts | Sort-Object Port) {
            $portF = $p.Port.ToString().PadRight(5)
            $serviceF = $p.Service.PadRight(12)
            Write-Host "║ $portF ║ $serviceF ║ ✅ Ouvert ║" -ForegroundColor Green
        }
        
        Write-Host "╚═══════╩══════════════╩═════════╝" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Aucun port ouvert détecté" -ForegroundColor Yellow
    }
    
    Read-Host "`nAppuie sur Entrée"
}