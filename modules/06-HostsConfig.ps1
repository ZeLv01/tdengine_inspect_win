# Module 05: Hosts File Configuration
# Checks: FQDN from dnodes are configured in hosts file

function Get-HostsConfigInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Hosts File Configuration"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
        
        # Read hosts file
        $hostsContent = @()
        if (Test-Path $hostsFile) {
            $hostsContent = Get-Content $hostsFile -ErrorAction SilentlyContinue
        }
        
        # Parse hosts file entries
        $hostsEntries = @{}
        foreach ($line in $hostsContent) {
            $line = $line.Trim()
            if ($line -and -not $line.StartsWith('#')) {
                $parts = $line -split '\s+'
                if ($parts.Count -ge 2) {
                    $ip = $parts[0]
                    for ($i = 1; $i -lt $parts.Count; $i++) {
                        $hostname = $parts[$i].ToLower()
                        $hostsEntries[$hostname] = $ip
                    }
                }
            }
        }
        
        # Get cluster nodes from SHOW DNODES
        $clusterFQDNs = @()
        try {
            $dnodeResult = Invoke-TDengineQuery -Sql "SHOW DNODES" -Config $Config
            
            if ($dnodeResult.code -eq 0 -and $dnodeResult.data) {
                foreach ($dnode in $dnodeResult.data) {
                    $endpoint = if ($dnode.endpoint) { $dnode.endpoint } else { "" }
                    if ($endpoint) {
                        # Extract FQDN from endpoint (format: fqdn:port)
                        $fqdn = ($endpoint -split ':')[0].ToLower()
                        if ($fqdn -and $fqdn -ne "localhost" -and $fqdn -ne "127.0.0.1") {
                            $clusterFQDNs += $fqdn
                        }
                    }
                }
            }
        } catch {
            Write-Warning "Failed to get dnode FQDNs: $_"
        }
        
        # Check each FQDN against hosts file
        $configuredNodes = @()
        $missingNodes = @()
        
        foreach ($fqdn in $clusterFQDNs) {
            if ($hostsEntries.ContainsKey($fqdn)) {
                $configuredNodes += @{
                    "FQDN" = $fqdn
                    "IP" = $hostsEntries[$fqdn]
                    "Source" = "hosts"
                }
            } else {
                # Try DNS resolution
                try {
                    $dnsEntry = [System.Net.Dns]::GetHostEntry($fqdn)
                    $ip = $dnsEntry.AddressList[0].IPAddressToString
                    $configuredNodes += @{
                        "FQDN" = $fqdn
                        "IP" = $ip
                        "Source" = "DNS"
                    }
                } catch {
                    $missingNodes += $fqdn
                }
            }
        }
        
        $result.Data = @{
            "Hosts File" = $hostsFile
            "Total Hosts Entries" = $hostsEntries.Count
            "Cluster FQDNs" = $clusterFQDNs.Count
            "Configured Nodes" = $configuredNodes
            "Missing Nodes" = $missingNodes
        }
        
        $result.Details += "Hosts File Configuration"
        $result.Details += "Hosts File: $hostsFile"
        $result.Details += "Cluster Nodes: $($clusterFQDNs.Count)"
        $result.Details += "Configured: $($configuredNodes.Count)"
        $result.Details += ""
        
        if ($configuredNodes.Count -gt 0) {
            $result.Details += ""
            $result.Details += "Configured Nodes:"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "{0,-30} {1,-20} {2}" -f "FQDN", "IP", "Source"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($node in $configuredNodes) {
                $result.Details += "{0,-30} {1,-20} {2}" -f $node.FQDN, $node.IP, $node.Source
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        }
        
        # Report missing nodes
        if ($missingNodes.Count -gt 0) {
            $result.Status = "Warning"
            $result.Issues += "Missing FQDN entries in hosts file: $($missingNodes -join ', ')"
            $result.Details += ""
            $result.Details += "Missing Nodes (not in hosts file and cannot resolve via DNS):"
            foreach ($node in $missingNodes) {
                $result.Details += "  - $node"
            }
        }
        
        # If no cluster FQDNs found
        if ($clusterFQDNs.Count -eq 0) {
            $result.Details += "No cluster FQDNs found from SHOW DNODES"
            $result.Details += "This may be a standalone instance"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve hosts configuration: $_"
    }
    
    return $result
}
