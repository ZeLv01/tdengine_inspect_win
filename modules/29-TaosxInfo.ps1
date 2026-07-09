# Module 29: TaosX Status
# Checks: Query information_schema.ins_xnode_tasks and ins_xnodes
# to verify taosx tasks are running and nodes are online.

function Get-TaosxInfo {
    param(
        [object]$Config
    )

    $result = @{
        Name = "TaosX Status"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
        Tables = @()
    }

    try {
        # ===== Query 1: ins_xnode_tasks =====
        $result.Details += "===== TaosX Tasks ====="

        $tasksResult = Invoke-TDengineQuery -Sql 'SELECT id, name, status, reason, `to` FROM information_schema.ins_xnode_tasks' -Config $Config

        if ($tasksResult.code -eq 0 -and $tasksResult.data -and $tasksResult.data.Count -gt 0) {
            $taskRows = @()
            foreach ($row in $tasksResult.data) {
                $id     = if ($row.id -ne $null)     { $row.id }     else { "N/A" }
                $name   = if ($row.name -ne $null)   { $row.name }   else { "N/A" }
                $status = if ($row.status -ne $null) { $row.status } else { "N/A" }
                $reason = if ($row.reason -ne $null) { $row.reason } else { "" }
                $to     = if ($row.to -ne $null)     { $row.to }     else { "N/A" }

                $result.Details += "Task #${id}: ${name} | status=${status} | reason=${reason} | to=${to}"

                if ($status -ne "running") {
                    $result.Status = "Critical"
                    $result.Issues += "Task '$name' (id=$id) status is '$status', expected 'running'"
                }

                $taskRows += @(, @($id, $name, $status, $reason, $to))
            }
            $result.Tables += @{
                Caption = "TaosX Tasks (ins_xnode_tasks)"
                Headers = @("ID", "Name", "Status", "Reason", "To")
                Rows = $taskRows
            }
        } else {
            $result.Details += "(No tasks found or query returned no data)"
            if ($tasksResult.code -ne 0) {
                $result.Issues += "Query ins_xnode_tasks failed: $($tasksResult.desc)"
            }
        }

        # ===== Query 2: ins_xnodes =====
        $result.Details += ""
        $result.Details += "===== TaosX Nodes ====="

        $nodesResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_xnodes" -Config $Config

        if ($nodesResult.code -eq 0 -and $nodesResult.data -and $nodesResult.data.Count -gt 0) {
            $nodeRows = @()
            foreach ($row in $nodesResult.data) {
                $id          = if ($row.id -ne $null)          { $row.id }          else { "N/A" }
                $url         = if ($row.url -ne $null)         { $row.url }         else { "N/A" }
                $status      = if ($row.status -ne $null)      { $row.status }      else { "N/A" }
                $createTime  = if ($row.create_time -ne $null) { $row.create_time } else { "N/A" }
                $updateTime  = if ($row.update_time -ne $null) { $row.update_time } else { "N/A" }

                $result.Details += "Node #${id}: ${url} | status=${status} | created=${createTime}"

                if ($status -ne "online") {
                    if ($result.Status -eq "Pass") { $result.Status = "Critical" }
                    $result.Issues += "Node '$url' (id=$id) status is '$status', expected 'online'"
                }

                $nodeRows += @(, @($id, $url, $status, $createTime, $updateTime))
            }
            $result.Tables += @{
                Caption = "TaosX Nodes (ins_xnodes)"
                Headers = @("ID", "URL", "Status", "Create Time", "Update Time")
                Rows = $nodeRows
            }
        } else {
            $result.Details += "(No nodes found or query returned no data)"
            if ($nodesResult.code -ne 0) {
                $result.Issues += "Query ins_xnodes failed: $($nodesResult.desc)"
            }
        }

        # If we added issues but status was not set to Critical, set to Warning
        if ($result.Issues.Count -gt 0 -and $result.Status -eq "Pass") {
            $result.Status = "Warning"
        }

    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to query TaosX information: $_"
    }

    return $result
}
