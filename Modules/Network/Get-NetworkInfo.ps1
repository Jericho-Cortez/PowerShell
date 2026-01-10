function Get-NetworkInfo {
    Write-Host "`n🌐 INFORMATIONS RÉSEAU" -ForegroundColor Cyan
    Write-Host "═══════════════════════" -ForegroundColor Cyan
    
    $networkConfig = Get-NetIPConfiguration | Where-Object {
        $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq "Up"
    } | Select-Object -First 1
    
    if (-not $networkConfig) {
        Write-Host "`n❌ Impossible de détecter la configuration réseau" -ForegroundColor Red
        Read-Host "`nAppuie sur Entrée"
        return
    }
    
    $localIP = $networkConfig.IPv4Address.IPAddress
    $gateway = $networkConfig.IPv4DefaultGateway.NextHop
    
    Write-Host "`n📍 IP Locale : $localIP" -ForegroundColor Yellow
    Write-Host "🚪 Passerelle : $gateway" -ForegroundColor Yellow
    
    try {
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 3).ip
        Write-Host "🌍 IP Publique : $publicIP" -ForegroundColor Yellow
    } catch {
        Write-Host "🌍 IP Publique : Non disponible" -ForegroundColor Yellow
    }
    
    $dns = $networkConfig.DNSServer.ServerAddresses -join ", "
    Write-Host "🔍 DNS : $dns" -ForegroundColor Yellow
    
    Write-Host "`n📡 Tests de connexion :" -ForegroundColor Yellow
    if (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet) {
        Write-Host "   ✅ Internet actif" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Pas de connexion" -ForegroundColor Red
    }
    
    Write-Host "`n🔍 Scanner le réseau local ?" -ForegroundColor Yellow
    $scan = Read-Host "Cela peut prendre 1-2 minutes (O/N)"
    
    if ($scan -eq 'O' -or $scan -eq 'o') {
        Write-Host "`n🔎 SCAN DU RÉSEAU" -ForegroundColor Cyan
        Write-Host "════════════════" -ForegroundColor Cyan
        
        $ipParts = $localIP.Split('.')
        $networkBase = "$($ipParts[0]).$($ipParts[1]).$($ipParts[2])"
        
        if (Get-Command nmap -ErrorAction SilentlyContinue) {
            Write-Host "`n⚡ Scan avec nmap..." -ForegroundColor Yellow
            $nmapOutput = nmap -sn "$networkBase.0/24" 2>&1
            $lines = $nmapOutput -split "`n"
            $devices = @()
            
            foreach ($line in $lines) {
                if ($line -match "Nmap scan report for (.+) \((\d+\.\d+\.\d+\.\d+)\)") {
                    $devices += [PSCustomObject]@{ IP = $matches[2]; Name = $matches[1]; MAC = "" }
                } elseif ($line -match "Nmap scan report for (\d+\.\d+\.\d+\.\d+)") {
                    $devices += [PSCustomObject]@{ IP = $matches[1]; Name = ""; MAC = "" }
                }
            }
        } else {
            Write-Host "`n⏳ Scan en cours..." -ForegroundColor Yellow
            $devices = @()
            
            1..254 | ForEach-Object -Parallel {
                $ip = "$using:networkBase.$_"
                if (Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1) {
                    try { $name = [System.Net.Dns]::GetHostEntry($ip).HostName }
                    catch { $name = "" }
                    [PSCustomObject]@{ IP = $ip; Name = $name; MAC = "" }
                }
            } -ThrottleLimit 50 | ForEach-Object {
                $devices += $_
                Write-Host "." -NoNewline -ForegroundColor Green
            }
            Write-Host ""
        }
        
        $arpTable = arp -a
        foreach ($device in $devices) {
            $arpEntry = $arpTable | Select-String $device.IP
            if ($arpEntry) {
                $parts = $arpEntry -split '\s+'
                if ($parts.Count -ge 3) { $device.MAC = $parts[2] }
            }
        }
        
        if ($devices.Count -gt 0) {
            Write-Host "`n✅ $($devices.Count) appareil(s) trouvé(s)`n" -ForegroundColor Green
            
            Write-Host "╔═══════════════╦════════════════════════════════╦═══════════════════╗" -ForegroundColor Gray
            Write-Host "║ IP            ║ Nom d'hôte                     ║ MAC               ║" -ForegroundColor Gray
            Write-Host "╠═══════════════╬════════════════════════════════╬═══════════════════╣" -ForegroundColor Gray
            
            foreach ($device in $devices | Sort-Object {[System.Version]$_.IP}) {
                $ipF = $device.IP.PadRight(13)
                
                $nameDisplay = if ($device.IP -eq $localIP) { "💻 TON PC" }
                              elseif ($device.IP -eq $gateway) { "🌐 ROUTEUR/BOX" }
                              elseif ($device.Name) { $device.Name }
                              else { "Appareil inconnu" }
                
                $nameF = $nameDisplay.PadRight(30).Substring(0, 30)
                $macF = $device.MAC.PadRight(17)
                
                $color = if ($device.IP -eq $localIP) { "Green" }
                        elseif ($device.IP -eq $gateway) { "Cyan" }
                        else { "White" }
                
                Write-Host "║ $ipF ║ $nameF ║ $macF ║" -ForegroundColor $color
            }
            
            Write-Host "╚═══════════════╩════════════════════════════════╩═══════════════════╝" -ForegroundColor Gray
        } else {
            Write-Host "`n⚠️  Aucun appareil détecté" -ForegroundColor Yellow
        }
    }
    
    Read-Host "`nAppuie sur Entrée"
}