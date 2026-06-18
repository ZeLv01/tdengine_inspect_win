# Module 03: Network Information
# Checks: FQDN, network adapter name and bandwidth

function Get-NetworkInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Network Information"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Get FQDN
        $fqdn = [System.Net.Dns]::GetHostEntry("localhost").HostName
        $hostname = $env:COMPUTERNAME
        
        # Get active network adapters
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object Name, InterfaceDescription, LinkSpeed, MacAddress
        
        $adapterList = @()
        foreach ($adapter in $adapters) {
            $adapterList += @{
                "Name" = $adapter.Name
                "Description" = $adapter.InterfaceDescription
                "LinkSpeed" = $adapter.LinkSpeed
                "MACAddress" = $adapter.MacAddress
            }
        }
        
        # Get IP addresses
        $ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object IPAddress, InterfaceAlias
        
        $result.Data = @{
            "FQDN" = $fqdn
            "Hostname" = $hostname
            "Active Adapters" = $adapterList
            "IP Addresses" = $ipAddresses | ForEach-Object { "$($_.IPAddress) ($($_.InterfaceAlias))" }
        }
        
        $result.Details += "FQDN: $fqdn"
        $result.Details += "Hostname: $hostname"
        $result.Details += "Active Adapters:"
        foreach ($adapter in $adapterList) {
            $result.Details += "  - $($adapter.Name): $($adapter.LinkSpeed)"
        }
        $result.Details += "IP Addresses:"
        foreach ($ip in $ipAddresses) {
            $result.Details += "  - $($ip.IPAddress) ($($ip.InterfaceAlias))"
        }
        
        # Check if any adapter has low bandwidth (less than 1 Gbps)
        foreach ($adapter in $adapters) {
            if ($adapter.LinkSpeed -match '(\d+)\s*Mbps') {
                $speedMbps = [int]$Matches[1]
                if ($speedMbps -lt 1000) {
                    $result.Status = "Warning"
                    $result.Issues += "Network adapter '$($adapter.Name)' has low bandwidth: $($adapter.LinkSpeed)"
                }
            }
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve network information: $_"
    }
    
    return $result
}

