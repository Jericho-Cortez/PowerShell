function Start-SecurityAudit {
    Write-Host "`n🔐 AUDIT DE SÉCURITÉ WINDOWS" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════" -ForegroundColor Cyan
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportFolder = "$env:USERPROFILE\Documents\SecurityAudits"
    
    if (-not (Test-Path $reportFolder)) {
        New-Item -Path $reportFolder -ItemType Directory -Force | Out-Null
    }
    
    $reportFile = "$reportFolder\SecurityAudit_$timestamp.html"
    $csvFile = "$reportFolder\SecurityAudit_$timestamp.csv"
    
    Write-Host "`n🔍 Scan en cours (30-60 secondes)...`n" -ForegroundColor Yellow
    
    # ═══════════════════════════════════════════════════════════
    # 1. INFORMATIONS SYSTÈME
    # ═══════════════════════════════════════════════════════════
    Write-Host "  [1/8] 💻 Informations système..." -ForegroundColor Gray
    
    $computerInfo = Get-ComputerInfo -Property CsName, OsName, OsVersion, OsBuildNumber, OsArchitecture
    $systemInfo = [PSCustomObject]@{
        ComputerName = $computerInfo.CsName
        OS = $computerInfo.OsName
        Version = $computerInfo.OsVersion
        Build = $computerInfo.OsBuildNumber
        Architecture = $computerInfo.OsArchitecture
    }
    
    # ═══════════════════════════════════════════════════════════
    # 2. WINDOWS DEFENDER
    # ═══════════════════════════════════════════════════════════
    Write-Host "  [2/8] 🛡️  Windows Defender..." -ForegroundColor Gray
    
    try {
        $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
        $defenderInfo = [PSCustomObject]@{
            Enabled = $defenderStatus.AntivirusEnabled
            LastScan = $defenderStatus.AntivirusScanAge
            SignatureAge = $defenderStatus.AntivirusSignatureAge
            RealTimeProtection = $defenderStatus.RealTimeProtectionEnabled
            TamperProtection = $defenderStatus.IsTamperProtected
            Status = if ($defenderStatus.AntivirusEnabled -and $defenderStatus.RealTimeProtectionEnabled) { "✅ ACTIF" } else { "❌ DÉSACTIVÉ" }
        }
    } catch {
        $defenderInfo = [PSCustomObject]@{
            Enabled = $false
            Status = "⚠️  NON DISPONIBLE"
        }
    }
    
    # ═══════════════════════════════════════════════════════════
    # 3. PARE-FEU
    # ═══════════════════════════════════════════════════════════
    Write-Host "  [3/8] 🔥 Pare-feu..." -ForegroundColor Gray
    
    $firewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled
    $firewallStatus = [PSCustomObject]@{
        Domain = ($firewallProfiles | Where-Object Name -eq 'Domain').Enabled
        Private = ($firewallProfiles | Where-Object Name -eq 'Private').Enabled
        Public = ($firewallProfiles | Where-Object Name -eq 'Public').Enabled
        Status = if (($firewallProfiles | Where-Object Enabled -eq $true).Count -eq 3) { "✅ ACTIF (tous profils)" } else { "⚠️  PARTIELLEMENT ACTIF" }
    }
    
    # ═══════════════════════════════════════════════════════════
    # 4. BITLOCKER
    # ═══════════════════════════════════════════════════════════
    Write-Host "  [4/8] 🔒 BitLocker..." -ForegroundColor Gray
    
    try {
        $bitlocker = Get-BitLockerVolume -ErrorAction Stop | Where-Object { $_.VolumeType -eq 'OperatingSystem' }
        $bitlockerInfo = [PSCustomObject]@{
            Volume = $bitlocker.MountPoint
            ProtectionStatus = $bitlocker.ProtectionStatus
            EncryptionPercentage = $bitlocker.EncryptionPercentage
            Status = if ($bitlocker.ProtectionStatus -eq 'On') { "✅ CHIFFRÉ" } else { "❌ NON CHIFFRÉ" }
        }
    } catch {
        $bitlockerInfo = [PSCustomObject]@{
            Status = "⚠️  NON DISPONIBLE"
        }
    }
    
    # ═══════════════════════════════════════════════════════════
    # 5. MISES À JOUR WINDOWS
    # ═══════════════════════════════════════════════════════════
    Write-Host "  [5/8] 📦 Mises à jour..." -ForegroundColor Gray
    
    $hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5
    $lastUpdate = $hotfixes | Select-Object -First 1
    $daysSinceUpdate = if ($lastUpdate.InstalledOn) { 
        (New-TimeSpan -Start $lastUpdate.InstalledOn -End (Get-Date)).Days 
    } else { 999 }
    
    $updateInfo = [PSCustomObject]@{
        LastUpdate = if ($lastUpdate.InstalledOn) { $lastUpdate.InstalledOn.ToString("dd/MM/yyyy") } else { "Inconnue" }
        DaysSince = $daysSinceUpdate
        RecentCount = $hotfixes.Count
        Status = if ($daysSinceUpdate -lt 30) { "✅ À JOUR" } elseif ($daysSinceUpdate -lt 90) { "⚠️  ANCIEN" } else { "❌ CRITIQUE" }
    }
    
    # ═══════════════════════════════════════════════════════════
    # 6. SERVICES SUSPECTS
    # ═══════════════════════════════════════════════════════════
    Write-Host "  [6/8] ⚙️  Services critiques..." -ForegroundColor Gray
    
    $dangerousServices = @('Telnet', 'SNMP', 'RemoteRegistry', 'RemoteAccess', 'LanmanServer')
    $activeRiskyServices = @()
    
    foreach ($svc in $dangerousServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            $activeRiskyServices += [PSCustomObject]@{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = "❌ ACTIF (RISQUE)"
            }
        }
    }
    
    # Services auto non démarrés
    $stoppedAutoServices = Get-Service -ErrorAction SilentlyContinue | Where-Object { 
        $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' 
    } | Select-Object -First 10
    
    # ═══════════════════════════════════════════════════════════
    # 7. ÉVÉNEMENTS SÉCURITÉ (DERNIÈRES 24H)
    # ═══════════════════════════════════════════════════════════
    Write-Host "  [7/8] 📋 Événements sécurité..." -ForegroundColor Gray
    
    $since = (Get-Date).AddDays(-1)
    
    # Tentatives login échouées
    try {
        $failedLogins = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            Id = 4625
            StartTime = $since
        } -ErrorAction Stop | Select-Object -First 10
        $failedLoginCount = $failedLogins.Count
    } catch {
        $failedLoginCount = 0
    }
    
    # Nouveaux services installés
    try {
        $newServices = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Id = 7045
            StartTime = $since
        } -ErrorAction Stop | Select-Object -First 5
        $newServicesCount = $newServices.Count
    } catch {
        $newServicesCount = 0
    }
    
    # Comptes verrouillés
    try {
        $lockedAccounts = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            Id = 4740
            StartTime = $since
        } -ErrorAction Stop
        $lockedAccountsCount = $lockedAccounts.Count
    } catch {
        $lockedAccountsCount = 0
    }
    
    $eventInfo = [PSCustomObject]@{
        FailedLogins = $failedLoginCount
        NewServices = $newServicesCount
        LockedAccounts = $lockedAccountsCount
        Status = if ($failedLoginCount -gt 10) { "⚠️  ACTIVITÉ SUSPECTE" } else { "✅ NORMAL" }
    }
    
    # ═══════════════════════════════════════════════════════════
    # 8. PORTS OUVERTS (TOP 20)
    # ═══════════════════════════════════════════════════════════
    Write-Host "  [8/8] 🔌 Ports ouverts..." -ForegroundColor Gray
    
    $openPorts = Get-NetTCPConnection -State Listen | 
        Select-Object LocalPort, @{Name='Process';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}} |
        Group-Object LocalPort | 
        Select-Object @{Name='Port';Expression={$_.Name}}, @{Name='Process';Expression={$_.Group[0].Process}} |
        Sort-Object {[int]$_.Port} |
        Select-Object -First 20
    
    # Ports dangereux connus
    $dangerousPorts = @(23, 21, 135, 139, 445, 3389)
    $riskyOpenPorts = $openPorts | Where-Object { $dangerousPorts -contains [int]$_.Port }
    
    # ═══════════════════════════════════════════════════════════
    # GÉNÉRATION RAPPORT HTML
    # ═══════════════════════════════════════════════════════════
    Write-Host "`n📊 Génération du rapport..." -ForegroundColor Cyan
    
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Audit Sécurité - $($systemInfo.ComputerName)</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #f5f5f5; margin: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #333; margin-top: 30px; border-left: 4px solid #0078d4; padding-left: 10px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f9f9f9; }
        .good { color: #107c10; font-weight: bold; }
        .warning { color: #ff8c00; font-weight: bold; }
        .bad { color: #d13438; font-weight: bold; }
        .info-box { background: #e7f3ff; border-left: 4px solid #0078d4; padding: 15px; margin: 15px 0; }
        .stat { display: inline-block; margin: 10px 20px 10px 0; }
        .stat-label { color: #666; font-size: 0.9em; }
        .stat-value { font-size: 1.5em; font-weight: bold; color: #0078d4; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 Audit de Sécurité Windows</h1>
        <div class="info-box">
            <strong>Machine :</strong> $($systemInfo.ComputerName) | 
            <strong>OS :</strong> $($systemInfo.OS) | 
            <strong>Date :</strong> $(Get-Date -Format "dd/MM/yyyy HH:mm")
        </div>
        
        <h2>📊 Résumé Exécutif</h2>
        <div class="stat">
            <div class="stat-label">Defender</div>
            <div class="stat-value $(if ($defenderInfo.Enabled) {'good'} else {'bad'})">$($defenderInfo.Status)</div>
        </div>
        <div class="stat">
            <div class="stat-label">Pare-feu</div>
            <div class="stat-value $(if ($firewallStatus.Domain -and $firewallStatus.Private -and $firewallStatus.Public) {'good'} else {'warning'})">$($firewallStatus.Status)</div>
        </div>
        <div class="stat">
            <div class="stat-label">BitLocker</div>
            <div class="stat-value $(if ($bitlockerInfo.ProtectionStatus -eq 'On') {'good'} else {'bad'})">$($bitlockerInfo.Status)</div>
        </div>
        <div class="stat">
            <div class="stat-label">Mises à jour</div>
            <div class="stat-value $(if ($updateInfo.DaysSince -lt 30) {'good'} elseif ($updateInfo.DaysSince -lt 90) {'warning'} else {'bad'})">$($updateInfo.Status)</div>
        </div>
        
        <h2>🛡️ Windows Defender</h2>
        <table>
            <tr><th>Critère</th><th>Valeur</th></tr>
            <tr><td>État</td><td class="$(if ($defenderInfo.Enabled) {'good'} else {'bad'})">$(if ($defenderInfo.Enabled) {'Activé'} else {'Désactivé'})</td></tr>
            <tr><td>Protection temps réel</td><td class="$(if ($defenderInfo.RealTimeProtection) {'good'} else {'bad'})">$(if ($defenderInfo.RealTimeProtection) {'Activée'} else {'Désactivée'})</td></tr>
            <tr><td>Âge des signatures</td><td>$($defenderInfo.SignatureAge) jour(s)</td></tr>
            <tr><td>Dernier scan</td><td>Il y a $($defenderInfo.LastScan) jour(s)</td></tr>
        </table>
        
        <h2>🔥 Configuration Pare-feu</h2>
        <table>
            <tr><th>Profil</th><th>État</th></tr>
            <tr><td>Domaine</td><td class="$(if ($firewallStatus.Domain) {'good'} else {'bad'})">$(if ($firewallStatus.Domain) {'Activé'} else {'Désactivé'})</td></tr>
            <tr><td>Privé</td><td class="$(if ($firewallStatus.Private) {'good'} else {'bad'})">$(if ($firewallStatus.Private) {'Activé'} else {'Désactivé'})</td></tr>
            <tr><td>Public</td><td class="$(if ($firewallStatus.Public) {'good'} else {'bad'})">$(if ($firewallStatus.Public) {'Activé'} else {'Désactivé'})</td></tr>
        </table>
        
        <h2>📦 Mises à Jour Windows</h2>
        <table>
            <tr><th>Critère</th><th>Valeur</th></tr>
            <tr><td>Dernière mise à jour</td><td>$($updateInfo.LastUpdate)</td></tr>
            <tr><td>Jours depuis MAJ</td><td class="$(if ($updateInfo.DaysSince -lt 30) {'good'} elseif ($updateInfo.DaysSince -lt 90) {'warning'} else {'bad'})">$($updateInfo.DaysSince)</td></tr>
            <tr><td>Mises à jour récentes (90j)</td><td>$($updateInfo.RecentCount)</td></tr>
        </table>
        
        <h2>⚙️ Services Suspects</h2>
        $(if ($activeRiskyServices.Count -gt 0) {
            "<table><tr><th>Service</th><th>Nom</th><th>État</th></tr>"
            foreach ($svc in $activeRiskyServices) {
                "<tr><td>$($svc.Name)</td><td>$($svc.DisplayName)</td><td class='bad'>$($svc.Status)</td></tr>"
            }
            "</table>"
        } else {
            "<p class='good'>✅ Aucun service dangereux actif détecté</p>"
        })
        
        <h2>📋 Événements Sécurité (24h)</h2>
        <table>
            <tr><th>Type</th><th>Nombre</th><th>Sévérité</th></tr>
            <tr><td>Tentatives login échouées</td><td>$($eventInfo.FailedLogins)</td><td class="$(if ($eventInfo.FailedLogins -gt 10) {'warning'} else {'good'})">$(if ($eventInfo.FailedLogins -gt 10) {'⚠️ Élevé'} else {'✅ Normal'})</td></tr>
            <tr><td>Nouveaux services</td><td>$($eventInfo.NewServices)</td><td>$(if ($eventInfo.NewServices -gt 0) {'⚠️ À vérifier'} else {'✅ Aucun'})</td></tr>
            <tr><td>Comptes verrouillés</td><td>$($eventInfo.LockedAccounts)</td><td class="$(if ($eventInfo.LockedAccounts -gt 0) {'warning'} else {'good'})">$(if ($eventInfo.LockedAccounts -gt 0) {'⚠️ Incidents'} else {'✅ Aucun'})</td></tr>
        </table>
        
        <h2>🔌 Ports Ouverts (Top 20)</h2>
        <table>
            <tr><th>Port</th><th>Processus</th><th>Risque</th></tr>
            $(foreach ($port in $openPorts) {
                $isDangerous = $dangerousPorts -contains [int]$port.Port
                $riskClass = if ($isDangerous) {'bad'} else {'good'}
                $riskText = if ($isDangerous) {'⚠️ Risque'} else {'✅ Normal'}
                "<tr><td>$($port.Port)</td><td>$($port.Process)</td><td class='$riskClass'>$riskText</td></tr>"
            })
        </table>
        
        <h2>💡 Recommandations</h2>
        <ul>
            $(if (-not $defenderInfo.Enabled) { "<li class='bad'>❌ Activer Windows Defender immédiatement</li>" })
            $(if ($defenderInfo.SignatureAge -gt 7) { "<li class='warning'>⚠️ Mettre à jour les signatures Defender (âge: $($defenderInfo.SignatureAge) jours)</li>" })
            $(if ($updateInfo.DaysSince -gt 30) { "<li class='warning'>⚠️ Installer les mises à jour Windows (dernière: $($updateInfo.DaysSince) jours)</li>" })
            $(if ($bitlockerInfo.ProtectionStatus -ne 'On') { "<li class='bad'>❌ Activer BitLocker pour chiffrer le disque système</li>" })
            $(if ($activeRiskyServices.Count -gt 0) { "<li class='bad'>❌ Désactiver les services dangereux détectés</li>" })
            $(if ($eventInfo.FailedLogins -gt 10) { "<li class='warning'>⚠️ Analyser les tentatives de connexion suspectes</li>" })
            $(if ($riskyOpenPorts.Count -gt 0) { "<li class='warning'>⚠️ Fermer les ports dangereux exposés : $($riskyOpenPorts.Port -join ', ')</li>" })
            <li class='good'>✅ Programmer des audits réguliers (hebdomadaire recommandé)</li>
        </ul>
        
        <div class="info-box">
            <strong>📁 Fichiers générés :</strong><br>
            HTML : $reportFile<br>
            CSV : $csvFile
        </div>
    </div>
</body>
</html>
"@
    
    $htmlReport | Out-File -FilePath $reportFile -Encoding UTF8
    
    # ═══════════════════════════════════════════════════════════
    # EXPORT CSV
    # ═══════════════════════════════════════════════════════════
    $csvData = [PSCustomObject]@{
        Date = Get-Date -Format "dd/MM/yyyy HH:mm"
        Computer = $systemInfo.ComputerName
        DefenderEnabled = $defenderInfo.Enabled
        FirewallActive = ($firewallStatus.Domain -and $firewallStatus.Private -and $firewallStatus.Public)
        BitLockerOn = ($bitlockerInfo.ProtectionStatus -eq 'On')
        DaysSinceUpdate = $updateInfo.DaysSince
        FailedLogins24h = $eventInfo.FailedLogins
        RiskyServicesActive = $activeRiskyServices.Count
        DangerousPortsOpen = $riskyOpenPorts.Count
    }
    
    $csvData | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
    
    # ═══════════════════════════════════════════════════════════
    # AFFICHAGE RÉSULTATS
    # ═══════════════════════════════════════════════════════════
    Write-Host "`n✅ AUDIT TERMINÉ !`n" -ForegroundColor Green
    
    Write-Host "📊 RÉSUMÉ :" -ForegroundColor Cyan
    Write-Host "  • Defender       : $($defenderInfo.Status)" -ForegroundColor $(if ($defenderInfo.Enabled) {'Green'} else {'Red'})
    Write-Host "  • Pare-feu       : $($firewallStatus.Status)" -ForegroundColor $(if ($firewallStatus.Domain -and $firewallStatus.Private -and $firewallStatus.Public) {'Green'} else {'Yellow'})
    Write-Host "  • BitLocker      : $($bitlockerInfo.Status)" -ForegroundColor $(if ($bitlockerInfo.ProtectionStatus -eq 'On') {'Green'} else {'Red'})
    Write-Host "  • Mises à jour   : $($updateInfo.Status) ($($updateInfo.DaysSince) jours)" -ForegroundColor $(if ($updateInfo.DaysSince -lt 30) {'Green'} elseif ($updateInfo.DaysSince -lt 90) {'Yellow'} else {'Red'})
    Write-Host "  • Logins échoués : $($eventInfo.FailedLogins) (24h)" -ForegroundColor $(if ($eventInfo.FailedLogins -gt 10) {'Yellow'} else {'Green'})
    Write-Host "  • Services risqués : $($activeRiskyServices.Count)" -ForegroundColor $(if ($activeRiskyServices.Count -gt 0) {'Red'} else {'Green'})
    Write-Host "  • Ports dangereux : $($riskyOpenPorts.Count)" -ForegroundColor $(if ($riskyOpenPorts.Count -gt 0) {'Yellow'} else {'Green'})
    
    Write-Host "`n📁 Rapports générés :" -ForegroundColor Cyan
    Write-Host "  • HTML : $reportFile" -ForegroundColor White
    Write-Host "  • CSV  : $csvFile" -ForegroundColor White
    
    Write-Host "`n💡 Ouvrir le rapport HTML ? (O/N)" -ForegroundColor Yellow
    $open = Read-Host
    
    if ($open -eq 'O' -or $open -eq 'o') {
        Start-Process $reportFile
    }
    
    Read-Host "`nAppuie sur Entrée pour retourner au menu"
}