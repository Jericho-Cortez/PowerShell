function Search-Files {
    Write-Host "`n🔍 RECHERCHE AVANCÉE DE FICHIERS" -ForegroundColor Cyan
    Write-Host "═════════════════════════════════" -ForegroundColor Cyan
    
    Write-Host "`n📋 Type de recherche :" -ForegroundColor Yellow
    Write-Host "  [1] Recherche par nom de fichier" -ForegroundColor White
    Write-Host "  [2] Recherche dans le contenu (texte)" -ForegroundColor White
    Write-Host "  [3] Les deux" -ForegroundColor White
    
    $searchType = Read-Host "`nChoix (1-3)"
    
    $fileName = ""
    $contentQuery = ""
    
    if ($searchType -eq '1' -or $searchType -eq '3') {
        $fileName = Read-Host "`nNom du fichier"
    }
    
    if ($searchType -eq '2' -or $searchType -eq '3') {
        $contentQuery = Read-Host "Texte dans le contenu"
    }
    
    Write-Host "`n⚡ Recherche Windows Search Index..." -ForegroundColor Yellow
    
    try {
        $connection = New-Object -ComObject ADODB.Connection
        $recordSet = New-Object -ComObject ADODB.Recordset
        
        $connection.Open("Provider=Search.CollatorDSO;Extended Properties='Application=Windows';")
        
        # Construire la requête SQL selon le type
        $whereClause = @()
        
        if ($fileName) {
            $whereClause += "System.FileName LIKE '%$fileName%'"
        }
        
        if ($contentQuery) {
            $whereClause += "FREETEXT('$contentQuery')"
        }
        
        $sql = @"
            SELECT TOP 50 
                System.ItemName, 
                System.ItemPathDisplay, 
                System.Size,
                System.DateModified,
                System.ItemType
            FROM SYSTEMINDEX 
            WHERE $($whereClause -join ' AND ')
            ORDER BY System.DateModified DESC
"@
        
        $recordSet.Open($sql, $connection)
        
        $results = @()
        
        while (-not $recordSet.EOF) {
            $results += [PSCustomObject]@{
                Name = $recordSet.Fields.Item("System.ItemName").Value
                Path = $recordSet.Fields.Item("System.ItemPathDisplay").Value
                Size = $recordSet.Fields.Item("System.Size").Value
                Modified = $recordSet.Fields.Item("System.DateModified").Value
                Type = $recordSet.Fields.Item("System.ItemType").Value
            }
            $recordSet.MoveNext()
        }
        
        $recordSet.Close()
        $connection.Close()
        
        if ($results.Count -gt 0) {
            Write-Host "`n✅ $($results.Count) résultat(s) trouvé(s) :`n" -ForegroundColor Green
            
            for ($i = 0; $i -lt $results.Count; $i++) {
                $result = $results[$i]
                
                $size = if ($result.Size -gt 1MB) { "$([math]::Round($result.Size / 1MB, 2)) MB" }
                       elseif ($result.Size -gt 1KB) { "$([math]::Round($result.Size / 1KB, 2)) KB" }
                       else { "$($result.Size) B" }
                
                $modified = if ($result.Modified) { $result.Modified.ToString("dd/MM/yyyy HH:mm") } else { "N/A" }
                
                $icon = switch -Wildcard ($result.Type) {
                    "*.txt" { "📝" }
                    "*.pdf" { "📄" }
                    "*.docx" { "📘" }
                    "*.xlsx" { "📊" }
                    "*.ps1" { "⚡" }
                    "*.py" { "🐍" }
                    "*.js" { "🟨" }
                    default { "📄" }
                }
                
                Write-Host "  [$($i+1)] $icon $($result.Name)" -ForegroundColor White
                Write-Host "      $($result.Path)" -ForegroundColor Gray
                Write-Host "      Taille: $size | Modifié: $modified" -ForegroundColor DarkGray
                Write-Host ""
            }
            
            Write-Host "`n📋 Actions :" -ForegroundColor Yellow
            Write-Host "  [N] Ouvrir un résultat par numéro" -ForegroundColor White
            Write-Host "  [F] Ouvrir le dossier d'un résultat" -ForegroundColor White
            Write-Host "  [C] Copier le chemin d'un résultat" -ForegroundColor White
            Write-Host "  [0] Retour" -ForegroundColor Gray
            
            $action = Read-Host "`nAction (N/F/C/0)"
            
            switch ($action) {
                'N' { 
                    $num = Read-Host "Numéro du résultat (1-$($results.Count))"
                    
                    if ($num -match '^\d+$' -and [int]$num -le $results.Count -and [int]$num -gt 0) {
                        $selectedPath = $results[[int]$num - 1].Path
                        
                        try {
                            # Utiliser Invoke-Item qui gère mieux les chemins avec espaces
                            Invoke-Item -LiteralPath $selectedPath
                            Write-Host "`n✅ Fichier ouvert" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n❌ Impossible d'ouvrir le fichier" -ForegroundColor Red
                            Write-Host "💡 Le fichier nécessite peut-être une application spécifique" -ForegroundColor Yellow
                            
                            $openFolder = Read-Host "Ouvrir le dossier à la place ? (O/N)"
                            if ($openFolder -eq 'O' -or $openFolder -eq 'o') {
                                $folder = Split-Path -LiteralPath $selectedPath
                                explorer.exe "/select,`"$selectedPath`""
                                Write-Host "✅ Dossier ouvert avec le fichier sélectionné" -ForegroundColor Green
                            }
                        }
                    }
                    else {
                        Write-Host "❌ Numéro invalide" -ForegroundColor Red
                    }
                }
                'F' { 
                    $num = Read-Host "Numéro du résultat (1-$($results.Count))"
                    
                    if ($num -match '^\d+$' -and [int]$num -le $results.Count -and [int]$num -gt 0) {
                        $selectedPath = $results[[int]$num - 1].Path
                        
                        # Ouvrir l'explorateur avec le fichier sélectionné
                        explorer.exe "/select,`"$selectedPath`""
                        Write-Host "`n✅ Dossier ouvert avec le fichier sélectionné" -ForegroundColor Green
                    }
                    else {
                        Write-Host "❌ Numéro invalide" -ForegroundColor Red
                    }
                }
                'C' { 
                    $num = Read-Host "Numéro du résultat (1-$($results.Count))"
                    
                    if ($num -match '^\d+$' -and [int]$num -le $results.Count -and [int]$num -gt 0) {
                        $selectedPath = $results[[int]$num - 1].Path
                        Set-Clipboard -Value $selectedPath
                        Write-Host "`n✅ Chemin copié : $selectedPath" -ForegroundColor Green
                    }
                    else {
                        Write-Host "❌ Numéro invalide" -ForegroundColor Red
                    }
                }
            }
        }
        else {
            Write-Host "`n⚠️  Aucun résultat" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "`n❌ Erreur : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Vérifie l'indexation Windows : Paramètres > Recherche" -ForegroundColor Cyan
    }
    
    Read-Host "`nAppuie sur Entrée pour retourner au menu"
}