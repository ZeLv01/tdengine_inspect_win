# TDengine Inspection Tool for Windows

A comprehensive, production-ready inspection tool for TDengine database running on Windows operating systems. Designed for database administrators and DevOps teams to quickly assess TDengine cluster health, identify potential issues, and generate professional inspection reports.

[中文文档](README_CN.md)

## Highlights & Advantages

### Why Choose This Tool?

| Feature | Description |
|---------|-------------|
| **26 Inspection Items** | Industry-leading coverage: OS, CPU, Memory, Network, Database, Security, Performance |
| **Dual Connection Mode** | WebSocket (REST API) + Native protocol, no TDengine client needed for remote inspection |
| **Zero Dependencies (EXE)** | Standalone executable, no PowerShell modules or runtime required |
| **Professional HTML Report** | Interactive sidebar navigation, color-coded status, alert summary |
| **One-Click Build** | Single command to package EXE with all modules embedded |
| **Modular Architecture** | Each inspection item is an independent module, easy to extend and maintain |

### Technical Advantages

1. **WebSocket First Design**
   - Uses port 6041 (REST API) by default
   - No need to install TDengine client on inspection machine
   - Supports remote inspection across networks
   - Automatic fallback to native protocol (port 6030) when needed

2. **Intelligent Report Generation**
   - Left sidebar navigation for quick access to any section
   - Top-level alert summary shows all failures and warnings at a glance
   - Color-coded badges: Pass (green), Warning (yellow), Fail (red)
   - Monospace tables for perfect alignment of technical data
   - Responsive design works on any screen size

3. **Enterprise-Grade Features**
   - License/Authorization monitoring (expiry, usage limits)
   - Slow query analysis with configurable lookback period
   - User permission audit (root password, monitor users)
   - Service version consistency check across all components
   - Error log aggregation by service (taosd, taosAdapter, taosKeeper, taosx, taos-explorer)

4. **Flexible Deployment**
   - **Script Mode**: Run directly with PowerShell for development/debugging
   - **EXE Mode**: Package as standalone executable for distribution
   - **Scheduled Mode**: Integrate with Windows Task Scheduler for automated inspections

5. **Configurable Thresholds**
   - Disk usage warning/critical levels
   - CPU usage thresholds
   - License expiry warning days
   - Slow query lookback period and threshold
   - All thresholds configurable via `config.json`

### Use Cases

- **Production Health Checks**: Regular automated inspections to catch issues early
- **Pre-Deployment Verification**: Verify environment before deploying TDengine upgrades
- **Compliance Auditing**: Check security settings, user permissions, firewall status
- **Performance Monitoring**: Track slow queries, resource usage, replica status
- **Support Escalation**: Generate comprehensive reports for TDengine support team

## Prerequisites

- Windows PowerShell 5.1 or later
- Network access to TDengine server (for WebSocket connection on port 6041)
- TDengine installed (only required for native connection mode)

## Quick Start

### 1. Configure Connection

Edit `config.json` to set your TDengine connection parameters:

```json
{
    "connection": {
        "method": "websocket",
        "server": "localhost",
        "port": 6041,
        "user": "root",
        "password": "taosdata",
        "useSSL": false,
        "timeout": 30
    }
}
```

### 2. Run Inspection

**Option A: Quick Start (Recommended)**

Double-click `Run-Inspection.bat` and select from the menu:
- Option 1: Run Inspection (default settings)
- Option 2: Run Inspection and open report automatically
- Option 3: Run Inspection in quiet mode

**Option B: PowerShell**

```powershell
.\TDengine-Inspect.ps1
```

> **Note**: If you get an execution policy error, run `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process` first, or use `Run-Inspection.bat` which bypasses this automatically.

### 3. View Report

The HTML report will be generated in the `output` folder. Open it in any web browser.

## Build EXE

You can package the tool as a standalone executable for easier distribution.

### Prerequisites

- Windows PowerShell 5.1 or later
- PS2EXE module (will be installed automatically if missing)

### Build Steps

```powershell
# Run the build script
.\build.ps1

# Or with clean build (removes previous build artifacts)
.\build.ps1 -Clean
```

### Build Output

The build creates a `dist/` directory containing:

```
dist/
├── TDengine-Inspect.exe    # Standalone executable
├── config.json              # Configuration file
└── README.md                # Documentation
```

### Using the EXE

```cmd
REM Basic usage
TDengine-Inspect.exe

REM Custom config file
TDengine-Inspect.exe -ConfigPath "C:\config\my-config.json"

REM Quiet mode
TDengine-Inspect.exe -Quiet

REM Open report after generation
TDengine-Inspect.exe -OpenReport
```

### Distribution

To distribute the tool:

1. Run `.\build.ps1` to create the EXE
2. Copy the entire `dist/` folder to the target machine
3. Edit `config.json` to match the target environment
4. Run `TDengine-Inspect.exe`

**Note**: The EXE does not require PowerShell modules or script files - everything is embedded.

## Usage Examples

### Basic Usage

```powershell
# Run inspection with default settings
.\TDengine-Inspect.ps1

# Run and open report automatically
.\TDengine-Inspect.ps1 -OpenReport

# Quiet mode (less console output)
.\TDengine-Inspect.ps1 -Quiet

# Custom config file
.\TDengine-Inspect.ps1 -ConfigPath "C:\config\my-config.json"

# Custom output path
.\TDengine-Inspect.ps1 -OutputPath "C:\reports\inspection.html"
```

### Task Scheduler

```powershell
# Interactive setup
.\TaskScheduler.ps1

# List scheduled tasks
.\TaskScheduler.ps1 -List

# Remove a task
.\TaskScheduler.ps1 -Remove -TaskName "TDengine Inspection"

# Run task immediately
.\TaskScheduler.ps1 -Run -TaskName "TDengine Inspection"
```

> **Note**: If you get an execution policy error, run `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process` first.

## Configuration

### Connection Methods

| Method | Port | Description |
|--------|------|-------------|
| websocket | 6041 | REST API via HTTP/HTTPS (recommended for remote) |
| native | 6030 | Native TDengine protocol (requires client) |

### Thresholds

```json
{
    "thresholds": {
        "diskUsageWarning": 85,
        "diskUsageCritical": 95,
        "cpuUsageWarning": 80,
        "licenseExpiryDays": 90,
        "licenseUsagePercent": 80,
        "slowQueryLookbackDays": 30,
        "slowQueryThresholdMs": 10000
    }
}
```

### Cluster Nodes

```json
{
    "cluster": {
        "nodes": ["node1.example.com", "node2.example.com", "node3.example.com"],
        "replica": 3
    }
}
```

## Inspection Items

| # | Item | Description |
|---|------|-------------|
| 1 | System Information | OS name, version, kernel, uptime |
| 2 | CPU Information | Model, architecture, core count |
| 3 | Memory Information | Total, used, free memory |
| 4 | Network Information | FQDN, adapters, bandwidth |
| 5 | Data Directory | Mount path, filesystem, space usage |
| 6 | Hosts Configuration | FQDN to IP mappings |
| 7 | Dnode Information | Vnodes, status, reboot time |
| 8 | Mnode Information | Role, status, role time |
| 9 | Database List | All databases including log/audit |
| 10 | Database Create SQL | Database creation statements |
| 11 | Super Table Statistics | Super table counts by database |
| 12 | Super Table Details | Column counts, widths, subtables |
| 13 | Disk Distribution | Super table disk distribution |
| 14 | Disk Usage | Free space below 15% threshold |
| 15 | CPU Usage | High usage (>80%) |
| 16 | Firewall Status | Windows Firewall status |
| 17 | Service Version | taos/taosd/taosAdapter versions |
| 18 | Service Status | taosd, adapter, keeper, explorer status |
| 19 | Error Logs | ERROR messages in log files |
| 20 | Database Users | User list, roles, permissions |
| 21 | License/Authorization | Usage limits, expiry date |
| 22 | Slow Queries | Slow queries in last N days |
| 23 | Replica Count | Cluster replication factor |
| 24 | Database Variables | TDengine configuration parameters |
| 25 | Vnodes Leader Distribution | Leader count per dnode, balance check |
| 26 | Database Measure Points | Total measure points per database |

## Report Status

- **Pass**: Check completed successfully, no issues found
- **Warning**: Check completed with warnings that should be reviewed
- **Fail**: Critical issue found that requires immediate attention

## Remote Inspection

For remote inspection without installing TDengine client:

1. Use WebSocket connection (port 6041)
2. Ensure taosAdapter is running on remote server
3. Configure firewall to allow port 6041

```json
{
    "connection": {
        "method": "websocket",
        "server": "192.168.1.100",
        "port": 6041,
        "user": "root",
        "password": "your_password"
    }
}
```

## Troubleshooting

### Authentication Failed

If you see `Authentication Failed!` at startup:
- Verify the `user` and `password` fields in `config.json`
- Ensure the user exists in TDengine
- The tool will exit immediately — no inspections will run until credentials are corrected

### Connection Failed

If you see `Connection Failed!` at startup:
- Verify TDengine services are running on the target server
- Check firewall settings (port 6041 for WebSocket, 6030 for native)
- Verify `server` and `port` fields in `config.json`
- Try switching `method` between `websocket` and `native`

### Permission Denied

- Run PowerShell as Administrator
- Check TDengine user permissions
- Verify Windows Firewall rules

### Execution Policy Error

If you get `running scripts is disabled on this system`:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```
Or use `Run-Inspection.bat` which handles this automatically.

### Report Not Generated

- Check output directory permissions
- Verify template file exists in `templates/`
- Check PowerShell execution policy

## File Structure

```
TDengine-Inspect/
├── TDengine-Inspect.ps1     # Main inspection script
├── Run-Inspection.bat       # Quick start batch file
├── build.ps1                 # EXE build script
├── config.json               # Configuration file
├── TaskScheduler.ps1         # Task scheduler setup
├── Test-Modules.ps1          # Module loading test
├── README.md                 # English documentation
├── README_CN.md              # Chinese documentation
├── CHANGELOG.md              # Version history
├── modules/                  # Inspection modules (26 items)
│   ├── 00-Connection.ps1    # Connection handling
│   ├── 01-SystemInfo.ps1    # System information
│   ├── 02-CPUInfo.ps1       # CPU information
│   ├── 03-MemoryInfo.ps1    # Memory information
│   ├── ...
│   ├── 25-VnodeLeader.ps1   # Vnodes leader distribution
│   └── 26-MeasurePoints.ps1 # Database measure points
├── templates/                # Report templates
│   └── report-template.html # HTML template
├── output/                   # Generated reports
└── dist/                     # Build output (EXE)
```

## Version History

### 1.6.1
- SQL identifiers now use backtick quoting for special characters, hyphens, Chinese names
- Early authentication failure detection with clear error messages
- Connection failure detection with server/port guidance
- Silent handling of "Table does not exist" for unsupported virtual supertables

### 1.6.0
- Fixed native query hanging (switched to stdin for SQL input)
- Added Compression_Ratio display in disk distribution
- Improved native output parsing

### 1.5.0
- Renamed status labels: Fail → Critical
- Improved fallback logic between WebSocket and native
- Better error messages for connection/auth failures

### 1.4.0
- Added item 26: Database Measure Points
- Added item 25: Vnodes Leader Distribution

### 1.3.0
- Added Vnodes Leader Distribution check

### 1.2.0
- Added EXE packaging support via build.ps1
- Professional HTML report with sidebar navigation
- Alert summary at report top

### 1.1.0
- Added sidebar navigation menu in HTML report
- Added Memory Information module
- Improved table formatting

### 1.0.0
- Initial release with 22 inspection items
- WebSocket and Native connection support
- HTML report generation
- Task scheduler integration

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## License

This tool is provided as-is for TDengine database inspection.

## Support

For issues or questions:
- Check TDengine documentation: https://docs.taosdata.com/
- Contact your TDengine administrator
