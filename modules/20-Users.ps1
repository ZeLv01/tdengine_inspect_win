# Module 20: Database Users
# Checks: 1. Root user default password not changed; 2. No monitoring user configured; 3. No regular users defined

function Get-UserInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Users"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        $userList = @()
        $querySuccess = $false
        
        # Method 1: Try SHOW USERS
        try {
            $userResult = Invoke-TDengineQuery -Sql "SHOW USERS" -Config $Config
            if ($userResult.code -eq 0 -and $userResult.data) {
                foreach ($user in $userResult.data) {
                    $userList += @{
                        "Name" = if ($user.name) { $user.name } else { "Unknown" }
                        "Is Super" = if ($user.super) { $user.super } else { 0 }
                        "Enabled" = if ($user.enable) { $user.enable } else { 1 }
                        "SysInfo" = if ($user.sysinfo) { $user.sysinfo } else { 1 }
                        "CreateDb" = if ($user.createdb) { $user.createdb } else { 0 }
                        "Create Time" = if ($user.create_time) { $user.create_time } else { "N/A" }
                        "Totp" = if ($user.totp) { $user.totp } else { 0 }
                        "Allowed Host" = if ($user.allowed_host) { $user.allowed_host } elseif ($user.'allowed_host') { $user.'allowed_host' } else { "N/A" }
                        "Allowed Datetime" = if ($user.allowed_datetime) { $user.allowed_datetime } elseif ($user.'allowed_datetime') { $user.'allowed_datetime' } else { "N/A" }
                        "Roles" = if ($user.roles) { $user.roles } else { "N/A" }
                        "Sec Levels" = if ($user.sec_levels) { $user.sec_levels } elseif ($user.'sec_levels') { $user.'sec_levels' } else { "N/A" }
                    }
                }
                $querySuccess = $true
            }
        } catch { }
        
        # Method 2: Try information_schema.ins_users
        if (-not $querySuccess) {
            try {
                $userResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_users" -Config $Config
                if ($userResult.code -eq 0 -and $userResult.data) {
                    foreach ($user in $userResult.data) {
                        $userList += @{
                            "Name" = if ($user.name) { $user.name } elseif ($user.user_name) { $user.user_name } else { "Unknown" }
                            "Is Super" = if ($user.super) { $user.super } else { 0 }
                            "Enabled" = if ($user.enable) { $user.enable } else { 1 }
                            "SysInfo" = if ($user.sysinfo) { $user.sysinfo } else { 1 }
                            "CreateDb" = if ($user.createdb) { $user.createdb } else { 0 }
                            "Create Time" = if ($user.create_time) { $user.create_time } else { "N/A" }
                            "Totp" = if ($user.totp) { $user.totp } else { 0 }
                            "Allowed Host" = if ($user.allowed_host) { $user.allowed_host } else { "N/A" }
                            "Allowed Datetime" = if ($user.allowed_datetime) { $user.allowed_datetime } else { "N/A" }
                            "Roles" = if ($user.roles) { $user.roles } else { "N/A" }
                            "Sec Levels" = if ($user.sec_levels) { $user.sec_levels } else { "N/A" }
                        }
                    }
                    $querySuccess = $true
                }
            } catch { }
        }
        
        # Categorize users
        $superUsers = @()
        $regularUsers = @()
        $monitorUsers = @()
        $rootUser = $null
        
        foreach ($user in $userList) {
            if ($user.Name -eq "root") {
                $rootUser = $user
                $superUsers += $user
            } elseif ($user.'Is Super' -eq 1 -or $user.'Is Super' -eq "1") {
                $superUsers += $user
            } else {
                $regularUsers += $user
            }
            if ($user.Name -match "monitor|exporter|keeper|prometheus") {
                $monitorUsers += $user
            }
        }
        
        $result.Data = @{
            "Total Users" = $userList.Count
            "Super Users" = $superUsers.Count
            "Regular Users" = $regularUsers.Count
            "Monitor Users" = $monitorUsers.Count
            "User List" = $userList
            "Root User" = $rootUser
        }
        
        $result.Details += "Database User Summary"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $result.Details += "Total Users: $($userList.Count) | Super: $($superUsers.Count) | Regular: $($regularUsers.Count)"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        if ($querySuccess) {
            $result.Details += ""
            $result.Details += "User Details:"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "{0,-12} {1,-8} {2,-9} {3,-9} {4,-10} {5,-20} {6,-6} {7,-30} {8}" -f "Name", "Super", "Enabled", "SysInfo", "CreateDb", "Create Time", "Totp", "Allowed Host", "Roles"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($user in $userList) {
                $result.Details += "{0,-12} {1,-8} {2,-9} {3,-9} {4,-10} {5,-20} {6,-6} {7,-30} {8}" -f $user.Name, $user.'Is Super', $user.Enabled, $user.SysInfo, $user.CreateDb, $user.'Create Time', $user.Totp, $user.'Allowed Host', $user.Roles
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            # Check 1: Root user info (password can't be verified remotely)
            if ($rootUser) {
                $result.Details += ""
                $result.Details += "Root User: $($rootUser.Name) - exists"
                # Password state cannot be checked via SQL; only a reminder
                $result.Details += "Reminder: If root password is still 'taosdata', change it for security."
            }
            
            # Check 2: Monitoring user
            if ($monitorUsers.Count -eq 0) {
                $result.Details += ""
                $result.Details += "Monitoring User: Not configured"
                $result.Issues += "Recommendation: Configure a dedicated monitoring user for taosKeeper/prometheus"
                $result.Status = "Warning"
            } else {
                $result.Details += ""
                $result.Details += "Monitoring Users: $($monitorUsers.Count) found"
            }
            
            # Check 3: Regular users
            if ($regularUsers.Count -eq 0) {
                $result.Details += ""
                $result.Details += "Regular Users: None"
                $result.Issues += "Recommendation: Create regular database users instead of using root for applications"
                $result.Status = "Warning"
            }
        } else {
            $result.Details += "User information not available via WebSocket"
        }
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to retrieve user information: $($_.Exception.Message)"
    }
    
    return $result
}
