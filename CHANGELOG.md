# Changelog

## [1.6.1] - 2026-06-17

### Fixed
- SQL identifiers now use backtick quoting to support special characters, hyphens, and Chinese names
- Modules 10, 12, 13: database/stable names wrapped in backticks

## [1.6.0] - 2026-06-17

### Fixed
- Native query hanging: switched from `-s` flag to stdin for SQL input (closes stdin so taos exits)
- ConvertFrom-NativeOutput: empty column values (like note field) no longer cause row parsing failure
- StableDisk: added Compression_Ratio display

## [1.5.6] - 2026-06-16

### Fixed
- Replica: SafeInt/SafeStr helpers handle NULL strings from taos native output
- Replica: Fixed missing $dbInfo assignment

## [1.5.5] - 2026-06-16

### Fixed
- DnodeInfo: switched from SHOW DNODES to SELECT * FROM information_schema.ins_dnodes
- MnodeInfo: switched from SHOW MNODES to SELECT * FROM information_schema.ins_mnodes
- ConvertFrom-NativeOutput: now returns PSCustomObject (not hashtable) for consistent property access
- Replica: handles both PSCustomObject and Hashtable data formats

## [1.5.4] - 2026-06-16

### Fixed
- Fallback logic: native failure now correctly falls back to WebSocket (port 6041)
- WebSocket data conversion: more robust column_meta format handling
- DnodeInfo: uses PSObject.Properties for robust property access
- Replica: uses information_schema.ins_databases instead of SHOW DATABASES
- Fixed "Unknown" database names in Replica module

## [1.5.3] - 2026-06-16

### Fixed
- Removed ArgumentList (requires .NET 5+, not available in Windows PowerShell 5.1)
- Password with special characters: `-p` directly followed by password (no space)
- Removed temp file for SQL - pass SQL directly via `-s` argument
- Fixed potential deadlock when reading stdout/stderr from taos process (async reads)

## [1.5.2] - 2026-06-16

### Fixed
- Native connection now uses Process with timeout (30s) to avoid hanging
- Connection test timeout 8s for native mode
- Fallback port switching: correctly swaps port when switching between WebSocket/Native
- Root password check: removed false-positive warning (password can't be verified via SQL)

## [1.5.1] - 2026-06-16

### Fixed
- Native fallback now uses fallback port (6030) instead of WebSocket port (6041)
- Authentication failures skip unnecessary fallback attempts
- Better error messages for connection/auth failures

## [1.5.0] - 2026-06-16

### Changed
- All status labels renamed: `Fail` → `Critical` (more accurate: inspection succeeded, result is critical)
- CSS classes updated: `.fail` → `.critical`
- `$_.Status` Where-Object count replaced with manual foreach+switch for reliability

## [1.4.0] - 2026-06-12

### Added
- New item 26: Database Measure Points
  - Queries total measure points (columns-1) per database from ins_tables
  - Shows sorted list by measure point count

## [1.3.0] - 2026-06-12

### Added
- New item 25: Vnodes Leader Distribution check
  - Queries leader count per dnode from ins_vnodes
  - Detects unbalanced leader distribution
  - Warns when dnodes have no leaders (recommend: BALANCE VGROUP LEADER)
  - Warns when one dnode has significantly more leaders than expected

## [1.2.0] - 2026-06-12

### Added
- EXE packaging support via build.ps1 (uses PS2EXE)
- build.ps1 generates standalone executable with all modules embedded
- Automatic TDengine icon download for EXE
- Automatic dist/ directory creation with config.json
- .gitignore for build artifacts

### Changed
- Updated README with EXE build instructions

## [1.1.5] - 2026-06-12

### Fixed
- Renamed confusing config key `slowQueryDays` → `slowQueryLookbackDays`
- Added `slowQueryThresholdMs` (10000 = 10s) to config for clarity
- Slow query SQL queries now use time-range filtering (WHERE start_time > NOW() - Nd)

## [1.1.4] - 2026-06-12

### Added
- New item 24: Database Variables (SHOW CLUSTER VARIABLES / SHOW VARIABLES)

### Fixed
- License module: Now properly extracts fields from SHOW GRANTS and SHOW GRANTS FULL
- Database List table: Increased column widths and improved alignment
- Dnode/Mnode tables: Increased column widths and unified separator format
- StableDisk/StableStats tables: Unified separator format and improved column widths

## [1.1.3] - 2026-06-12

### Fixed
- Slow query: Properly differentiates "table not found" vs "no data" vs "has slow queries"
- License module: Fixed empty output, now handles SHOW GRANTS data better
- Error log timestamps: Added support for TDengine log format (MM/dd HH:mm:ss)
- Error log messages: No longer truncated, shown in full
- Table alignment: Removed faulty HTML table conversion, all tables now display in correct monospace format

## [1.1.2] - 2026-06-12

### Fixed
- Fixed syntax error in ErrorLog module (line 122 duplicate)

## [1.1.1] - 2026-06-12

### Fixed
- Slow query: No slow queries now shows Pass status instead of Warning
- Firewall: Disabled firewall now shows Pass status (acceptable for internal networks)
- Error logs: Changed status from Fail to Warning for error messages
- All table formats now use consistent separator lines for proper alignment

### Improved
- License module: Improved table formatting
- Hosts module: Improved table formatting
- Database List: Improved table formatting

## [1.1.0] - 2026-06-12

### Added
- Added sidebar navigation menu in HTML report
- Navigation items show status badges (OK/!!/XX)
- Click navigation items to scroll to corresponding section

### Improved
- All table formats now use consistent separator lines (----------------------------------------------------------------------------------------------------)
- Version comparison now ignores ".enterprise" suffix
- Slow query module: Empty table shows "No slow queries found" instead of "not accessible"
- Database replica default value is now 1 instead of 0

## [1.0.9] - 2026-06-12

### Added
- Added Memory Information module (separated from CPU module)
- Added section numbers to all inspection items
- Added alert summary at the top of HTML report showing failures and warnings

### Improved
- CPU and Memory are now displayed as separate sections
- Mnode single-node warning message now suggests 3-node cluster for HA
- HTML report now shows numbered sections
- Alert summary provides quick overview of issues

## [1.0.8] - 2026-06-12

### Added
- Added memory information (total, used, free, usage %) to CPU module

### Improved
- Hosts module: Now checks cluster FQDNs from SHOW DNODES against hosts file
- Mnode module: Shows role_time instead of reboot_time
- Database List: Removed Cache/Blocks columns, cleaner display
- Super Table Stats: Changed to count by database using GROUP BY
- Super Table Disk: Excludes system databases (log, audit)
- Version module: Uses taos -V, taosd -V, taosadapter -V etc. for version info
- HTML Report: Added proper table formatting with CSS styles
- HTML Report: Tables are now rendered as HTML tables for better readability

## [1.0.7] - 2026-06-12

### Improved
- Dnode/Mnode modules: Added reboot_time display, improved table formatting
- Database List: Now uses information_schema.ins_databases for complete info
- Super Table Statistics: Excludes system databases (log, audit)
- Version module: Improved display format, handles missing version info
- License module: Changed to list format display for better readability
- Slow Query: Added log.taosd_slow_sql_detail table, multiple fallback options

## [1.0.6] - 2026-06-12

### Fixed
- Fixed slow query module - tables may not exist via WebSocket
- Added multiple fallback table names for slow query detection
- Improved error handling to avoid triggering connection fallback

## [1.0.5] - 2026-06-12

### Fixed
- Fixed script hanging when unsupported SQL commands trigger fallback
- Improved error handling to avoid unnecessary fallback attempts
- License module now uses direct WebSocket call for ins_grants query

## [1.0.4] - 2026-06-12

### Fixed
- Fixed "Operation not supported" error for SHOW USERS via WebSocket/REST API
- Fixed "Operation not supported" error for SHOW GRANTS via WebSocket/REST API
- Added fallback to information_schema.ins_users table for user info
- Added graceful handling when commands are not supported via REST API

## [1.0.3] - 2026-06-12

### Fixed
- Fixed CPU usage check module that was waiting 30 minutes for sampling
- Changed CPU check to only get current usage instead of long historical sampling

## [1.0.2] - 2026-06-12

### Fixed
- Fixed SQL variable expansion issue in modules 09, 10, 11, 12
- Fixed WebSocket response data format handling (convert array to object)
- Improved data property access in all modules for robustness
- Added better error handling for property access

### Changed
- Updated connection module to convert WebSocket response data to object format
- Updated all modules to handle both object and hashtable data formats
- Improved error messages throughout

## [1.0.1] - 2026-06-12

### Fixed
- Fixed module loading issue: `Export-ModuleMember` can only be called from within a module
- Removed `Export-ModuleMember` from all module files
- Fixed `Get-Config` function parameter naming conflict
- Improved module loading with better error handling
- Added `Test-Modules.ps1` script to verify module loading

### Changed
- Updated main script to load connection module separately first
- Improved error messages for module loading failures

## [1.0.0] - 2026-06-12

### Added
- Initial release
- 22 inspection items covering system, network, database, and security
- WebSocket (port 6041) and Native (port 6030) connection support
- HTML report generation with interactive features
- Task scheduler integration for automated inspections
- Quick start batch file (Run-Inspection.bat)
- Comprehensive README documentation

### Features
- System information (OS, CPU, network)
- Database configuration (data directory, hosts, users)
- Runtime status (services, dnodes, mnodes)
- Performance metrics (disk, CPU, slow queries)
- Security compliance (firewall, license, replica count)
