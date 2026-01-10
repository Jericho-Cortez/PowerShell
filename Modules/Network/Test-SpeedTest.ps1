function Test-SpeedTest {
    Write-Host "`n🚀 TEST DE VITESSE" -ForegroundColor Cyan
    Write-Host "═══════════════════" -ForegroundColor Cyan
    
    Write-Host "`n📡 Test de latence..." -ForegroundColor Yellow
    try {
        $ping = Test-Connection -ComputerName "8.8.8.8" -Count 4 -ErrorAction Stop
        $avgPing = [math]::Round(($ping.Latency | Measure-Object -Average).Average, 2)
        
        if ($avgPing -gt 0) {
            Write-Host "   ✅ Latence : $avgPing ms" -ForegroundColor Green
            
            if ($avgPing -lt 20) {
                Write-Host "   🟢 Excellent" -ForegroundColor Green
            } elseif ($avgPing -lt 50) {
                Write-Host "   🟡 Bon" -ForegroundColor Yellow
            } else {
                Write-Host "   🔴 Élevé" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "   ❌ Erreur" -ForegroundColor Red
    }
    
    Write-Host "`n⬇️  Test de téléchargement..." -ForegroundColor Yellow
    
    $testUrls = @(
        @{Url="https://proof.ovh.net/files/10Mb.dat"; Size=10},
        @{Url="https://bouygues.testdebit.info/10M.iso"; Size=10}
    )
    
    $output = "$env:TEMP\speedtest_$(Get-Random).tmp"
    $success = $false
    
    foreach ($test in $testUrls) {
        try {
            Write-Host "   Tentative..." -ForegroundColor Gray
            
            $start = Get-Date
            Invoke-WebRequest -Uri $test.Url -OutFile $output -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            $end = Get-Date
            
            $duration = ($end - $start).TotalSeconds
            
            if ($duration -gt 0 -and (Test-Path $output)) {
                $fileSizeMB = (Get-Item $output).Length / 1MB
                
                if ($fileSizeMB -gt 0.001) {
                    $speedMbps = [math]::Round(($fileSizeMB * 8) / $duration, 2)
                    
                    Write-Host "   ✅ Vitesse : $speedMbps Mbps" -ForegroundColor Green
                    Write-Host "   📊 $([math]::Round($fileSizeMB, 2)) MB en $([math]::Round($duration, 2)) s" -ForegroundColor Gray
                    
                    if ($speedMbps -gt 100) {
                        Write-Host "   🟢 Très rapide (Fibre)" -ForegroundColor Green
                    } elseif ($speedMbps -gt 30) {
                        Write-Host "   🟡 Bon" -ForegroundColor Yellow
                    } else {
                        Write-Host "   🟠 Moyen" -ForegroundColor Yellow
                    }
                    
                    $success = $true
                }
                
                Remove-Item $output -Force -ErrorAction SilentlyContinue
                break
            }
        }
        catch {
            Write-Host "   ⚠️  Échec, test suivant..." -ForegroundColor Yellow
            continue
        }
    }
    
    if (-not $success) {
        Write-Host "   ⚠️  Test non disponible" -ForegroundColor Yellow
        Write-Host "   💡 Utilise speedtest.net" -ForegroundColor Cyan
    }
    
    Read-Host "`nAppuie sur Entrée"
}