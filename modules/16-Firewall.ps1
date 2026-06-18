# Module 15: Firewall Status
# Checks: Firewall service is not disabled

function Get-FirewallStatus {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Firewall Status"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Check Windows Firewall status
        $firewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
        
        if ($firewallProfiles) {
            $profileList = @()
            $enabledProfiles = @()
            $disabledProfiles = @()
            
            foreach ($profile in $firewallProfiles) {
                $profileInfo = @{
                    "Name" = $profile.Name
                    "Enabled" = $profile.Enabled
                    "DefaultInboundAction" = $profile.DefaultInboundAction
                    "DefaultOutboundAction" = $profile.DefaultOutboundAction
                }
                $profileList += $profileInfo
                
                if ($profile.Enabled) {
                    $enabledProfiles += $profile.Name
                } else {
                    $disabledProfiles += $profile.Name
                }
            }
            
            $result.Data = @{
                "Total Profiles" = $profileList.Count
                "Enabled Profiles" = $enabledProfiles
                "Disabled Profiles" = $disabledProfiles
                "Profile Details" = $profileList
            }
            
            $result.Details += "Windows Firewall Status"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "{0,-15} {1,-12} {2,-20} {3,-20}" -f "Profile", "Enabled", "Default Inbound", "Default Outbound"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($profile in $profileList) {
                $enabledStr = if ($profile.Enabled) { "Yes" } else { "No" }
                $result.Details += "{0,-15} {1,-12} {2,-20} {3,-20}" -f $profile.Name, $enabledStr, $profile.DefaultInboundAction, $profile.DefaultOutboundAction
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            # Firewall status - both enabled and disabled are acceptable
            if ($disabledProfiles.Count -gt 0) {
                $result.Details += ""
                $result.Details += "Note: Firewall is disabled on: $($disabledProfiles -join ', ')"
                $result.Details += "This is acceptable for internal/trusted networks."
            }
            
        } else {
            # Try alternative method
            $firewallService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
            
            if ($firewallService) {
                $result.Data = @{
                    "Service Name" = "mpssvc"
                    "Display Name" = $firewallService.DisplayName
                    "Status" = $firewallService.Status
                    "Start Type" = $firewallService.StartType
                }
                
                $result.Details += "Windows Firewall Service (mpssvc)"
                $result.Details += "Status: $($firewallService.Status)"
                $result.Details += "Start Type: $($firewallService.StartType)"
                
                if ($firewallService.Status -ne "Running") {
                    $result.Status = "Warning"
                    $result.Issues += "Windows Firewall service is not running (Status: $($firewallService.Status))"
                }
                
                if ($firewallService.StartType -eq "Disabled") {
                    $result.Status = "Warning"
                    $result.Issues += "Windows Firewall service is disabled"
                }
            } else {
                $result.Status = "Warning"
                $result.Issues += "Could not determine firewall status"
            }
        }
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to retrieve firewall status: $_"
    }
    
    return $result
}

