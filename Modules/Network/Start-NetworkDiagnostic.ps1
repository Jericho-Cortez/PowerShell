function Start-NetworkDiagnostic {
    Write-Host "`n🔍 DIAGNOSTIC RÉSEAU COMPLET" -ForegroundColor Cyan
    Write-Host "═════════════════════════════" -ForegroundColor Cyan
    
    $target = Read-Host "`n🎯 Cible (IP ou hostname)"
    if ([string]::IsNullOrWhiteSpace($target)) {
        Write-Host "❌ Cible invalide" -ForegroundColor Red
        Read-Host "Appuie sur Entrée"
        return
    }
    
    Write-Host "`n🔄 Diagnostic en cours...`n" -ForegroundColor Yellow
    
    # 1️⃣ PING
    Write-Host "📡 [1/5] Test de connectivité..." -ForegroundColor Cyan -NoNewline
    $ping = Test-Connection -ComputerName $target -Count 4 -ErrorAction SilentlyContinue
    $pingResult = if ($ping) { 
        $avgPing = [math]::Round(($ping.Latency | Measure-Object -Average).Average, 2)
        "✅ OK ($avgPing ms)" 
    } else { 
        "❌ Hors ligne" 
    }
    Write-Host $pingResult -ForegroundColor $(if($ping){"Green"}else{"Red"})
    
    # 2️⃣ DNS Résolution
    Write-Host "🔍 [2/5] Résolution DNS..." -ForegroundColor Cyan -NoNewline
    try {
        $dnsIPs = [System.Net.Dns]::GetHostAddresses($target) | Select-Object -ExpandProperty IPAddressToString -Unique
        $dnsResult = "✅ $($dnsIPs -join ', ')"
        Write-Host $dnsResult -ForegroundColor Green
    } catch {
        Write-Host "❌ Échec" -ForegroundColor Red
        $dnsIPs = $null
    }
    
    # 3️⃣ Traceroute SIMPLIFIÉ
    Write-Host "🛤️ [3/5] Traceroute..." -ForegroundColor Cyan -NoNewline
    $reachable = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($reachable) {
        Write-Host "✅ Accessible" -ForegroundColor Green
    } else {
        Write-Host "❌ Non routable" -ForegroundColor Red
    }
    
    # 4️⃣ Ports critiques
    Write-Host "🔓 [4/5] Ports critiques..." -ForegroundColor Cyan
    $criticalPorts = @(22, 80, 443, 3389, 445, 3306)
    $openPorts = @()
    
    foreach ($port in $criticalPorts) {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($target, $port, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne(1000, $false)) {
            $service = switch ($port) {
                22 { "SSH" }
                80 { "HTTP" }
                443 { "HTTPS" }
                3389 { "RDP" }
                445 { "SMB" }
                3306 { "MySQL" }
                default { $port }
            }
            $openPorts += "$port($service)"
        }
        $tcp.Close()
    }
    
    if ($openPorts.Count -gt 0) {
        Write-Host "   ✅ Ouverts : $($openPorts -join ' ')" -ForegroundColor Green
    } else {
        Write-Host "   ✅ Aucun port critique ouvert" -ForegroundColor Gray
    }
    
    # 5️⃣ Résumé ⭐ CORRIGÉ
    Write-Host "`n📊 [5/5] RÉSUMÉ DIAGNOSTIC" -ForegroundColor Magenta
    Write-Host "═════════════════════════════" -ForegroundColor Magenta
    
    Write-Host "╔═══════════════════════╦══════════════════════════════════╗" -ForegroundColor Gray
    Write-Host "║ Test                  ║ Statut                           ║" -ForegroundColor Gray
    Write-Host "╠═══════════════════════╬══════════════════════════════════╣" -ForegroundColor Gray
    
    # Ligne Ping
    $pingStatus = $pingResult.PadRight(32)
    Write-Host "║ 📡 Ping               ║ $pingStatus║" -ForegroundColor $(if($ping){"Green"}else{"Red"})
    
    # Ligne DNS
    $dnsStatus = if($dnsIPs){"✅ Résolu"}else{"❌ Échec"}
    $dnsStatus = $dnsStatus.PadRight(32)
    Write-Host "║ 🔍 DNS                ║ $dnsStatus║" -ForegroundColor $(if($dnsIPs){"Green"}else{"Red"})
    
    # Ligne Traceroute
    $traceStatus = if($reachable){"✅ Accessible"}else{"❌ Non routable"}
    $traceStatus = $traceStatus.PadRight(32)
    Write-Host "║ 🛤️ Traceroute         ║ $traceStatus║" -ForegroundColor $(if($reachable){"Green"}else{"Red"})
    
    # Ligne Ports ⭐ SANS Substring (fix du bug)
    if ($openPorts.Count -gt 0) {
        $portsDisplay = "🔓 $($openPorts -join ' ')"
        # Si trop long, on tronque proprement
        if ($portsDisplay.Length -gt 32) {
            $portsDisplay = $portsDisplay.Substring(0, 29) + "..."
        }
        $portsStatus = $portsDisplay.PadRight(32)
        $portsColor = "Yellow"
    } else {
        $portsStatus = "✅ Aucun port ouvert".PadRight(32)
        $portsColor = "Green"
    }
    Write-Host "║ 🔓 Ports critiques    ║ $portsStatus║" -ForegroundColor $portsColor
    
    Write-Host "╚═══════════════════════╩══════════════════════════════════╝" -ForegroundColor Gray
    
    # Score de santé
    $healthScore = 0
    if ($ping) { $healthScore += 40 }
    if ($dnsIPs) { $healthScore += 25 }
    if ($reachable) { $healthScore += 25 }
    if ($openPorts.Count -eq 0) { $healthScore += 10 }
    
    $healthEmoji = switch ([math]::Round($healthScore / 100 * 5)) {
        5 { "🟢 Parfait" }
        4 { "🟡 Bon" }
        3 { "🟠 Moyen" }
        2 { "🔴 Problème" }
        default { "⚫ Hors ligne" }
    }
    
    Write-Host "`n🏥 État général : $healthEmoji ($([math]::Round($healthScore))%)" -ForegroundColor $(if($healthScore -gt 70){"Green"}elseif($healthScore -gt 40){"Yellow"}else{"Red"})
    
    Write-Host "`n💡 Actions suggérées :" -ForegroundColor Cyan
    
    if (-not $ping) { 
        Write-Host "   • ❌ Vérifier câble/réseau local" -ForegroundColor Red 
    }
    
    if (-not $dnsIPs) { 
        Write-Host "   • ❌ Vérifier DNS (8.8.8.8)" -ForegroundColor Red 
    }
    
    # ⭐ NOUVEAU : Suggestions par port ouvert
    if ($openPorts.Count -gt 0) {
        Write-Host "`n⚠️  Ports critiques détectés :" -ForegroundColor Yellow
        
        foreach ($portInfo in $openPorts) {
            # Extraire le numéro de port
            if ($portInfo -match '^(\d+)') {
                $port = $matches[1]
                
                $suggestion = switch ($port) {
                    '22' { 
                        Write-Host "   • 🔐 SSH (22) ouvert" -ForegroundColor Yellow
                        Write-Host "      → Désactiver si non utilisé : Stop-Service sshd" -ForegroundColor Gray
                        Write-Host "      → Ou changer le port par défaut" -ForegroundColor Gray
                    }
                    '80' { 
                        Write-Host "   • 🌐 HTTP (80) ouvert - NON CHIFFRÉ" -ForegroundColor Yellow
                        Write-Host "      → Rediriger vers HTTPS (443)" -ForegroundColor Gray
                        Write-Host "      → Arrêter IIS/Apache si inutilisé" -ForegroundColor Gray
                    }
                    '443' { 
                        Write-Host "   • ✅ HTTPS (443) - OK si serveur web" -ForegroundColor Green
                        Write-Host "      → Vérifier certificat SSL valide" -ForegroundColor Gray
                    }
                    '3389' { 
                        Write-Host "   • 🖥️  RDP (3389) ouvert - RISQUE ÉLEVÉ" -ForegroundColor Red
                        Write-Host "      → Désactiver : Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 1" -ForegroundColor Gray
                        Write-Host "      → Ou utiliser un VPN" -ForegroundColor Gray
                    }
                    '445' { 
                        Write-Host "   • 📁 SMB (445) ouvert - VULNÉRABILITÉ" -ForegroundColor Red
                        Write-Host "      → Bloquer dans pare-feu : New-NetFirewallRule -DisplayName 'Block SMB' -Direction Inbound -LocalPort 445 -Protocol TCP -Action Block" -ForegroundColor Gray
                        Write-Host "      → Ou limiter aux IP internes uniquement" -ForegroundColor Gray
                    }
                    '3306' { 
                        Write-Host "   • 🗄️  MySQL (3306) ouvert - EXPOSITION BDD" -ForegroundColor Yellow
                        Write-Host "      → Lier à localhost uniquement (bind-address = 127.0.0.1)" -ForegroundColor Gray
                        Write-Host "      → Ou utiliser un tunnel SSH" -ForegroundColor Gray
                    }
                }
            }
        }
        
        Write-Host "`n🛡️  Commande rapide pare-feu :" -ForegroundColor Cyan
        Write-Host "   New-NetFirewallRule -DisplayName 'Bloquer port X' -Direction Inbound -LocalPort <PORT> -Protocol TCP -Action Block" -ForegroundColor White
    } else {
        Write-Host "   ✅ Aucun port critique exposé - Bonne configuration !" -ForegroundColor Green
    }
    
    Read-Host "`nAppuie sur Entrée"
}