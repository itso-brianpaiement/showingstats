## Monthly Run Instructions

### 1) One-click run (recommended)
Double-click:

- `CLICK ME TO GENERATE.cmd`

This runs everything automatically.

### 2) Verify keys file
This script expects a `keys.txt` file in the same folder with at least:

- `Endpoint URL: ...`
- `Server Token: ...`

If `keys.txt` is missing, copy `keys.template.txt` to `keys.txt` and fill in your values.

### 3) Run from terminal (optional)
From PowerShell:

```powershell
cd "C:\Users\user\Desktop\ITSO\Member Counts"
powershell -ExecutionPolicy Bypass -File .\run_member_counts.ps1
```

### 4) Review output files
Each run creates a month/day folder under:

- `.\output\Month_dd_ShowingSystemStats\`
Example: `.\output\February_27_ShowingSystemStats\`

Files produced:

- `.\output\Month_dd_ShowingSystemStats\data\summary.csv`
- `.\output\Month_dd_ShowingSystemStats\data\offices_selected.csv`
- `.\output\Month_dd_ShowingSystemStats\data\members_detail.csv`
- `.\output\Month_dd_ShowingSystemStats\data\duplicates_by_name.csv`
- `.\output\Month_dd_ShowingSystemStats\Showing_System_Member_Count_Month.csv` (template-style output)

### GitHub packaging

- Safe to commit:
  - `run_member_counts.ps1`
  - `CLICK ME TO GENERATE.cmd`
  - `README.md`
  - `keys.template.txt`
- Do not commit:
  - `keys.txt` (contains secrets)
  - `output\` files

`.gitignore` is included to block these by default.

### What the script counts

- Offices:
  - Active status (`A` or `Active`)
  - Source board from `OriginatingSystemName`:
    - `CAOR` or `Cornerstone` -> `Cornerstone`
    - `BRREA` or `Brantford` -> `BRREA`
  - Showing system mapped to:
    - `BRBY` or `BrokerBay` -> `BrokerBay`
    - `SA` or `ShowingTime` -> `ShowingTime`
- Members:
  - Active status (`A` or `Active`)
  - `MemberMlsSecurityClass` matches one of:
    - `F1` (or `BL`)
    - `F2` (or `BL2`)
    - `O1` (or `BRM`)
    - `SP1`, `SP2`, `SP3`, `SP4`, `SP5`
- Duplicate detection:
  - Name-based dedupe using normalized first + last name.
- Template report:
  - Builds a BrokerBay table with `CAOR`, `BRREA`, totals, cross-board duplicates, and billable total.
  - Builds a ShowingTime `CAOR` row filtered to members where `MemberMlsId` starts with `WR`, `CA`, or `KW`.

### Optional parameters

```powershell
.\run_member_counts.ps1 -KeysFile ".\keys.txt" -OutputRoot ".\output" -Top 200
```

`Top` must be between `1` and `200` (Bridge page limit).
