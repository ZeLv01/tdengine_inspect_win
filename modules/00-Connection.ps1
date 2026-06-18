# TDengine Connection Module
# Supports both WebSocket (REST API) and Native connection methods

function Get-Config {
    param(
        [string]$Path = (Join-Path $PSScriptRoot "..\config.json")
    )
    
    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }
    
    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Get-Base64Auth {
    param(
        [string]$User,
        [string]$Password
    )
    
    $authString = "${User}:${Password}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($authString)
    return [Convert]::ToBase64String($bytes)
}

function Test-WebSocketConnection {
    param(
        [string]$Server,
        [int]$Port,
        [string]$User,
        [string]$Password,
        [bool]$UseSSL = $false,
        [int]$Timeout = 10
    )
    
    try {
        $protocol = if ($UseSSL) { "https" } else { "http" }
        $url = "${protocol}://${Server}:${Port}/rest/login/${User}/${Password}"
        
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec $Timeout
        return $response.code -eq 0
    } catch {
        return $false
    }
}

function Invoke-TDengineQuery {
    param(
        [string]$Sql,
        [object]$Config = $null
    )
    
    if ($null -eq $Config) {
        $Config = Get-Config
    }
    
    $method = $Config.connection.method
    
    try {
        if ($method -eq "websocket") {
            $result = Invoke-WebSocketQuery -Sql $Sql -Config $Config
            return $result
        } else {
            $result = Invoke-NativeQuery -Sql $Sql -Config $Config
            return $result
        }
    } catch {
        $errorMsg = $_.Exception.Message
        
        # Don't fallback for SQL syntax issues
        if ($errorMsg -match "Operation not supported|unrecognized token|syntax error|Table does not exist") {
            throw $_
        }
        
        Write-Warning "Primary method ($method) failed: $errorMsg"
        
        if ($Config.fallback.enabled) {
            Write-Host "Attempting fallback..." -ForegroundColor Yellow
            try {
                if ($method -eq "websocket") {
                    $port = if ($Config.fallback.port -gt 0) { $Config.fallback.port } else { 6030 }
                    $oldMethod = $Config.connection.method
                    $Config.connection.method = "native"
                    $oldPort = $Config.connection.port
                    $Config.connection.port = $port
                    $result = Invoke-NativeQuery -Sql $Sql -Config $Config
                    $Config.connection.method = $oldMethod
                    $Config.connection.port = $oldPort
                    return $result
                } else {
                    $port = 6041
                    $oldMethod = $Config.connection.method
                    $Config.connection.method = "websocket"
                    $oldPort = $Config.connection.port
                    $Config.connection.port = $port
                    $result = Invoke-WebSocketQuery -Sql $Sql -Config $Config
                    $Config.connection.method = $oldMethod
                    $Config.connection.port = $oldPort
                    return $result
                }
            } catch {
                throw "Both methods failed: $_"
            }
        } else {
            throw $_
        }
    }
}

function Invoke-WebSocketQuery {
    param(
        [string]$Sql,
        [object]$Config
    )
    
    $server = $Config.connection.server
    $port = $Config.connection.port
    $user = $Config.connection.user
    $password = $Config.connection.password
    $useSSL = $Config.connection.useSSL
    $timeout = $Config.connection.timeout
    
    $protocol = if ($useSSL) { "https" } else { "http" }
    $url = "${protocol}://${server}:${port}/rest/sql"
    
    $auth = Get-Base64Auth -User $user -Password $password
    $headers = @{
        "Authorization" = "Basic $auth"
        "Content-Type" = "text/plain"
    }
    
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $Sql -TimeoutSec $timeout
    
    if ($response.code -ne 0) {
        throw "TDengine error: $($response.desc)"
    }
    
    if ($response.column_meta -and $response.data) {
        $columns = @()
        foreach ($col in $response.column_meta) {
            if ($col -is [array] -and $col.Count -ge 1) {
                $columns += $col[0]
            } elseif ($col -is [string]) {
                $columns += $col
            } else {
                $columns += $col.ToString()
            }
        }
        
        if ($columns.Count -gt 0) {
            $objectData = @()
            foreach ($row in $response.data) {
                $obj = [ordered]@{}
                for ($i = 0; $i -lt $columns.Count; $i++) {
                    $colName = $columns[$i]
                    if ($i -lt $row.Count) {
                        $obj[$colName] = $row[$i]
                    } else {
                        $obj[$colName] = $null
                    }
                }
                $objectData += [PSCustomObject]$obj
            }
            $response.data = $objectData
        }
    }
    
    return $response
}

function Invoke-NativeQuery {
    param(
        [string]$Sql,
        [object]$Config
    )
    
    $server = $Config.connection.server
    $port = $Config.connection.port
    $user = $Config.connection.user
    $password = $Config.connection.password
    $output = ""; $exitCode = -1
    
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "taos"
        $psi.Arguments = "-h $server -P $port -u $user -p$password -s`"$Sql`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        
        $p = [System.Diagnostics.Process]::Start($psi)
        $outTask = $p.StandardOutput.ReadToEndAsync()
        
        if (-not $p.WaitForExit(15000)) {
            $p.Kill()
            throw "Native query timed out"
        }
        $output = $outTask.Result
        $exitCode = $p.ExitCode
        $p.Dispose()
        
        if (-not $output) { $output = "(empty)" }
        
        $logDir = ".\native_logs"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $shortSql = $Sql.Substring(0, [Math]::Min(40, $Sql.Length)) -replace '[^a-zA-Z0-9]', '_'
        [System.IO.File]::WriteAllText("$logDir\last_${shortSql}.txt", "Exit: $exitCode`r`n`r`n=== STDOUT ===`r`n$output")
        
        if ($exitCode -ne 0) { throw "Native query failed (exit: $exitCode). Output: $output" }
        if ($output -eq "(empty)") { return @{ code = 0; data = @(); rows = 0 } }
        return ConvertFrom-NativeOutput -Output $output
    } catch {
        Write-Warning "Native: $_"
        throw
    }
}

function Test-NativeConnection {
    param(
        [string]$Server,
        [int]$Port,
        [string]$User,
        [string]$Password
    )
    
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "taos"
        $psi.Arguments = "-h $Server -P $Port -u $User -p$Password -s`"SELECT 1;`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.CreateNoWindow = $true
        
        $p = [System.Diagnostics.Process]::Start($psi)
        if (-not $p.WaitForExit(5000)) { $p.Kill(); $p.Dispose(); return $false }
        $exitCode = $p.ExitCode
        $p.Dispose()
        return $exitCode -eq 0
    } catch {
        return $false
    }
}

function ConvertFrom-NativeOutput {
    param(
        [string]$Output
    )
    
    $lines = $Output -split "[\r\n]+" | Where-Object { $_ -match '\S' }
    
    $headerLine = $lines | Where-Object { $_ -match '\|' } | Select-Object -First 1
    if (-not $headerLine) {
        # No table format, try \G format
        return ConvertFrom-GFormat -Output $Output
    }
    
    $columns = $headerLine -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    
    $data = @()
    $dataLines = $lines | Where-Object { $_ -match '\|' -and $_ -ne $headerLine }
    
    foreach ($line in $dataLines) {
        $rawValues = $line -split '\|' | ForEach-Object { $_.Trim() }
        if ($rawValues.Count -gt 0 -and [string]::IsNullOrEmpty($rawValues[-1])) {
            $rawValues = $rawValues[0..($rawValues.Count - 2)]
        }
        while ($rawValues.Count -lt $columns.Count) { $rawValues += "" }
        if ($rawValues.Count -gt $columns.Count) { $rawValues = $rawValues[0..($columns.Count - 1)] }
        
        $row = [ordered]@{}
        for ($i = 0; $i -lt $columns.Count; $i++) {
            $row[$columns[$i]] = $rawValues[$i]
        }
        $data += [PSCustomObject]$row
    }
    
    return @{
        code = 0
        column_meta = $columns
        data = $data
        rows = $data.Count
    }
}

function ConvertFrom-GFormat {
    param([string]$Output)
    
    $lines = $Output -split "[\r\n]+" | Where-Object { $_ -match '\S' }
    $rows = @()
    $currentData = [ordered]@{}
    
    foreach ($line in $lines) {
        # Row separator
        if ($line -match '^\*+\s+\d+\.row\s+\*+') {
            if ($currentData.Count -gt 0) {
                $rows += [PSCustomObject]$currentData
                $currentData = [ordered]@{}
            }
            continue
        }
        # Key: Value pattern from \G format
        if ($line -match '^\s*([^:]+):\s*(.*)$') {
            $currentData[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    # Last row
    if ($currentData.Count -gt 0) {
        $rows += [PSCustomObject]$currentData
    }
    
    if ($rows.Count -gt 0) {
        return @{ code = 0; data = $rows; rows = $rows.Count }
    }
    
    # Try SHOW CREATE output
    foreach ($line in $lines) {
        if ($line -match 'CREATE\s+(DATABASE|STABLE|TABLE)\s+' -or $line -match 'Create\s+(Database|Stable)\s+') {
            $rows += [PSCustomObject]@{ 'Create Database' = $line.Trim() }
            return @{ code = 0; data = $rows; rows = 1 }
        }
    }
    
    return @{ code = 0; data = @(); rows = 0 }
}

function Get-TDengineServerInfo {
    param(
        [object]$Config = $null
    )
    
    if ($null -eq $Config) {
        $Config = Get-Config
    }
    
    $info = @{
        version = ""
        server = $Config.connection.server
        port = $Config.connection.port
        method = $Config.connection.method
    }
    
    try {
        $result = Invoke-TDengineQuery -Sql "SELECT server_version()" -Config $Config
        if ($result.data -and $result.data.Count -gt 0) {
            $info.version = $result.data[0].'server_version()'
        }
    } catch {
        Write-Warning "Failed to get server version: $_"
    }
    
    return $info
}

function Test-TDengineConnection {
    param(
        [object]$Config = $null
    )

    if ($null -eq $Config) {
        $Config = Get-Config
    }

    $server = $Config.connection.server
    $port = $Config.connection.port
    $user = $Config.connection.user
    $method = $Config.connection.method

    try {
        $result = Invoke-TDengineQuery -Sql "SELECT 1" -Config $Config
        if ($result.code -eq 0) {
            return @{ Success = $true; ErrorType = ""; Message = "" }
        } else {
            return @{ Success = $false; ErrorType = "query"; Message = $result.desc }
        }
    } catch {
        $errMsg = $_.Exception.Message

        # Detect authentication errors
        if ($errMsg -match "authentication|auth|login|password|user.*not.*exist|invalid.*user|permission.*denied|0x8000070[0-9a-fA-F]") {
            return @{
                Success = $false
                ErrorType = "auth"
                Message = "Authentication failed for user '$user' on ${server}:${port} ($method). Please check the username and password in config.json."
            }
        }

        # Detect connection errors (server unreachable)
        if ($errMsg -match "connect|timeout|refused|unreachable|No such host|could not resolve|Unable to connect") {
            return @{
                Success = $false
                ErrorType = "connection"
                Message = "Cannot connect to TDengine at ${server}:${port} ($method). Please check the server address and ensure TDengine is running."
            }
        }

        return @{ Success = $false; ErrorType = "unknown"; Message = $errMsg }
    }
}
