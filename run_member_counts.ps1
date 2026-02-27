param(
    [string]$KeysFile = "",
    [string]$OutputRoot = (Join-Path $PSScriptRoot "output"),
    [int]$Top = 200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($KeysFile)) {
    $candidateKeys = @(
        (Join-Path $PSScriptRoot "keys"),
        (Join-Path $PSScriptRoot "keys.txt")
    )

    $found = $candidateKeys | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($found) {
        $KeysFile = $found
    }
    else {
        # Default error target if neither exists.
        $KeysFile = $candidateKeys[0]
    }
}

if ($Top -lt 1 -or $Top -gt 200) {
    throw "Top must be between 1 and 200 (Bridge limit)."
}

function Read-KeyValueFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Keys file not found: $Path"
    }

    $map = @{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            return
        }

        $parts = $line -split ":", 2
        if ($parts.Count -ne 2) {
            return
        }

        $key = $parts[0].Trim()
        $val = $parts[1].Trim()
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $map[$key] = $val
        }
    }

    return $map
}

function Escape-ODataLiteral {
    param([string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    return $Value.Replace("'", "''")
}

function Invoke-BridgePagedQuery {
    param(
        [string]$StartUrl,
        [string]$EntityName,
        [int]$MaxPages = 5000
    )

    $all = New-Object System.Collections.Generic.List[object]
    $url = $StartUrl
    $page = 0

    while (-not [string]::IsNullOrWhiteSpace($url)) {
        $page++
        if ($page -gt $MaxPages) {
            throw "Exceeded max pages ($MaxPages) for $EntityName. Last URL: $url"
        }

        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 120
        if ($resp.PSObject.Properties.Name -contains "value" -and $resp.value) {
            foreach ($row in $resp.value) {
                $all.Add($row)
            }
        }

        if ($resp.PSObject.Properties.Name -contains "@odata.nextLink") {
            $url = [string]$resp."@odata.nextLink"
        }
        else {
            $url = $null
        }
    }

    return $all
}

function Normalize-Board {
    param([object]$Office)

    $candidates = @(
        [string]$Office.OriginatingSystemName,
        [string]$Office.OfficeAOR
    )

    foreach ($raw in $candidates) {
        if ([string]::IsNullOrWhiteSpace($raw)) {
            continue
        }

        $u = $raw.Trim().ToUpperInvariant()
        if ($u -eq "CAOR" -or $u -like "*CORNERSTONE*") {
            return "Cornerstone"
        }

        if ($u -eq "BRREA" -or $u -like "*BRANTFORD*") {
            return "BRREA"
        }
    }

    return $null
}

function Normalize-Vendor {
    param([string]$ShowingSystem)

    if ([string]::IsNullOrWhiteSpace($ShowingSystem)) {
        return $null
    }

    $u = $ShowingSystem.Trim().ToUpperInvariant()
    if ($u -eq "BRBY" -or $u -eq "BROKERBAY" -or $u -like "*BROKERBAY*") {
        return "BrokerBay"
    }

    if ($u -eq "SA" -or $u -eq "SHOWINGTIME" -or $u -like "*SHOWINGTIME*") {
        return "ShowingTime"
    }

    return $null
}

function Normalize-Text {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $t = $Text.ToUpperInvariant()
    $t = $t -replace "[^A-Z0-9 ]", " "
    $t = $t -replace "\s+", " "
    return $t.Trim()
}

function Get-NameKey {
    param([object]$Member)

    $first = Normalize-Text ([string]$Member.MemberFirstName)
    $last = Normalize-Text ([string]$Member.MemberLastName)
    $full = Normalize-Text ([string]$Member.MemberFullName)

    if ($last -or $first) {
        return "$last|$first"
    }

    if ($full) {
        return $full
    }

    return "NO_NAME|$($Member.MemberKey)"
}

function Get-DisplayName {
    param([object]$Member)

    $first = ([string]$Member.MemberFirstName).Trim()
    $last = ([string]$Member.MemberLastName).Trim()
    $full = ([string]$Member.MemberFullName).Trim()

    $parts = @()
    if ($first) {
        $parts += $first
    }
    if ($last) {
        $parts += $last
    }

    if ($parts.Count -gt 0) {
        return ($parts -join " ")
    }

    if ($full) {
        return $full
    }

    return [string]$Member.MemberKey
}

$config = Read-KeyValueFile -Path $KeysFile
$endpoint = [string]$config["Endpoint URL"]
$serverToken = [string]$config["Server Token"]

if ([string]::IsNullOrWhiteSpace($endpoint)) {
    throw "Endpoint URL missing in keys file."
}
if ([string]::IsNullOrWhiteSpace($serverToken)) {
    throw "Server Token missing in keys file."
}

$endpoint = $endpoint.Trim().TrimEnd("/")
$safeEndpoint = $endpoint

Write-Host "Pulling offices..."

$officeFilter = @(
    "(OfficeStatus eq 'A' or OfficeStatus eq 'Active')",
    "(OriginatingSystemName eq 'CAOR' or OriginatingSystemName eq 'Cornerstone' or OriginatingSystemName eq 'BRREA' or OriginatingSystemName eq 'Brantford')",
    "(ITSO_ShowingSystem eq 'BRBY' or ITSO_ShowingSystem eq 'SA' or ITSO_ShowingSystem eq 'BrokerBay' or ITSO_ShowingSystem eq 'ShowingTime')"
) -join " and "

$officeSelect = "OfficeKey,OfficeName,OfficeMlsId,OfficeStatus,OriginatingSystemName,OfficeAOR,ITSO_ShowingSystem"
$officeUrl = "{0}/Office?`$filter={1}&`$select={2}&`$top={3}&access_token={4}" -f `
    $safeEndpoint, `
    ([uri]::EscapeDataString($officeFilter)), `
    $officeSelect, `
    $Top, `
    ([uri]::EscapeDataString($serverToken))

$rawOffices = Invoke-BridgePagedQuery -StartUrl $officeUrl -EntityName "Office"

$officeByKey = @{}
foreach ($office in $rawOffices) {
    $officeKey = [string]$office.OfficeKey
    if ([string]::IsNullOrWhiteSpace($officeKey)) {
        continue
    }

    $board = Normalize-Board -Office $office
    if ($null -eq $board) {
        continue
    }

    $vendor = Normalize-Vendor -ShowingSystem ([string]$office.ITSO_ShowingSystem)
    if ($null -eq $vendor) {
        continue
    }

    if (-not $officeByKey.ContainsKey($officeKey)) {
        $officeByKey[$officeKey] = [pscustomobject]@{
            OfficeKey             = $officeKey
            OfficeName            = [string]$office.OfficeName
            OfficeMlsId           = [string]$office.OfficeMlsId
            OriginatingSystemName = [string]$office.OriginatingSystemName
            OfficeAOR             = [string]$office.OfficeAOR
            ShowingSystemRaw      = [string]$office.ITSO_ShowingSystem
            Vendor                = $vendor
            Board                 = $board
        }
    }
}

Write-Host ("Selected offices after board/vendor mapping: {0}" -f $officeByKey.Count)

if ($officeByKey.Count -eq 0) {
    throw "No offices found for the configured criteria."
}

Write-Host "Pulling members..."

$securityClauses = @(
    # F1 / F2 / O1 can show up as direct class codes or as BL / BL2 / BRM labels.
    "startswith(MemberMlsSecurityClass,'F1')",
    "startswith(MemberMlsSecurityClass,'F2')",
    "startswith(MemberMlsSecurityClass,'O1')",
    "contains(MemberMlsSecurityClass,'(F1)')",
    "contains(MemberMlsSecurityClass,'(F2)')",
    "contains(MemberMlsSecurityClass,'(O1)')",
    "startswith(MemberMlsSecurityClass,'BL2')",
    "startswith(MemberMlsSecurityClass,'BL ')",
    "startswith(MemberMlsSecurityClass,'BRM')",
    "startswith(MemberMlsSecurityClass,'SP1')",
    "startswith(MemberMlsSecurityClass,'SP2')",
    "startswith(MemberMlsSecurityClass,'SP3')",
    "startswith(MemberMlsSecurityClass,'SP4')",
    "startswith(MemberMlsSecurityClass,'SP5')"
)
$securityFilter = ($securityClauses -join " or ")

$memberFilter = "(MemberStatus eq 'A' or MemberStatus eq 'Active') and ({0})" -f $securityFilter

$memberSelect = "MemberKey,MemberFirstName,MemberLastName,MemberFullName,MemberStatus,MemberMlsSecurityClass,OfficeKey,MemberEmail,MemberMlsId"
$memberUrl = "{0}/Member?`$filter={1}&`$select={2}&`$top={3}&access_token={4}" -f `
    $safeEndpoint, `
    ([uri]::EscapeDataString($memberFilter)), `
    $memberSelect, `
    $Top, `
    ([uri]::EscapeDataString($serverToken))

$rawMembers = Invoke-BridgePagedQuery -StartUrl $memberUrl -EntityName "Member"
Write-Host ("Members returned from API filter: {0}" -f $rawMembers.Count)

$memberRows = New-Object System.Collections.Generic.List[object]
$seenMemberOffice = @{}

foreach ($member in $rawMembers) {
    $officeKey = [string]$member.OfficeKey
    if (-not $officeByKey.ContainsKey($officeKey)) {
        continue
    }

    $memberKey = [string]$member.MemberKey
    if ([string]::IsNullOrWhiteSpace($memberKey)) {
        continue
    }

    $dedupeAccountKey = "$memberKey|$officeKey"
    if ($seenMemberOffice.ContainsKey($dedupeAccountKey)) {
        continue
    }
    $seenMemberOffice[$dedupeAccountKey] = $true

    $office = $officeByKey[$officeKey]
    $nameKey = Get-NameKey -Member $member
    $displayName = Get-DisplayName -Member $member

    $memberRows.Add([pscustomobject]@{
        Board                  = $office.Board
        Vendor                 = $office.Vendor
        OfficeKey              = $office.OfficeKey
        OfficeName             = $office.OfficeName
        OfficeMlsId            = $office.OfficeMlsId
        OriginatingSystemName  = $office.OriginatingSystemName
        OfficeAOR              = $office.OfficeAOR
        MemberKey              = $memberKey
        MemberName             = $displayName
        MemberEmail            = [string]$member.MemberEmail
        MemberMlsId            = [string]$member.MemberMlsId
        MemberStatus           = [string]$member.MemberStatus
        MemberMlsSecurityClass = [string]$member.MemberMlsSecurityClass
        NameKey                = $nameKey
    })
}

Write-Host ("Members linked to selected offices: {0}" -f $memberRows.Count)

$summaryRows = New-Object System.Collections.Generic.List[object]
$duplicateRows = New-Object System.Collections.Generic.List[object]

$memberGroupMap = @{}
$groupedByMemberBoardVendor = $memberRows | Group-Object Board, Vendor
foreach ($memberGroup in $groupedByMemberBoardVendor) {
    $memberParts = $memberGroup.Name -split ",\s*"
    $memberBoard = $memberParts[0]
    $memberVendor = $memberParts[1]
    $memberGroupMap["$memberBoard|$memberVendor"] = $memberGroup.Group
}

$groupedByOfficeBoardVendor = $officeByKey.Values | Group-Object Board, Vendor
foreach ($officeGroup in $groupedByOfficeBoardVendor) {
    $parts = $officeGroup.Name -split ",\s*"
    $board = $parts[0]
    $vendor = $parts[1]
    $key = "$board|$vendor"
    $rows = @()
    if ($memberGroupMap.ContainsKey($key)) {
        $rows = $memberGroupMap[$key]
    }

    $officeCount = $officeGroup.Count
    $accountCount = $rows.Count
    $uniquePeopleCount = 0
    if ($accountCount -gt 0) {
        $uniquePeopleCount = ($rows | Select-Object -ExpandProperty NameKey -Unique).Count
    }
    $duplicateAccountCount = $accountCount - $uniquePeopleCount

    $summaryRows.Add([pscustomobject]@{
        Board                       = $board
        Vendor                      = $vendor
        OfficeCount                 = $officeCount
        MemberAccountCount          = $accountCount
        UniquePeopleByNameCount     = $uniquePeopleCount
        DuplicateAccountCountByName = $duplicateAccountCount
    })

    if ($rows.Count -gt 0) {
        $dupNameGroups = $rows | Group-Object NameKey | Where-Object { $_.Count -gt 1 }
        foreach ($dup in $dupNameGroups) {
            foreach ($row in $dup.Group) {
                $duplicateRows.Add([pscustomobject]@{
                    Board               = $row.Board
                    Vendor              = $row.Vendor
                    DuplicateName       = $row.MemberName
                    DuplicateNameKey    = $row.NameKey
                    DuplicateCountByName = $dup.Count
                    MemberKey           = $row.MemberKey
                    OfficeKey           = $row.OfficeKey
                    OfficeName          = $row.OfficeName
                    MemberEmail         = $row.MemberEmail
                    MemberStatus        = $row.MemberStatus
                    MemberMlsSecurityClass = $row.MemberMlsSecurityClass
                })
            }
        }
    }
}

$brokerBayRows = @($memberRows | Where-Object { $_.Vendor -eq "BrokerBay" })
$brokerCaorRows = @($brokerBayRows | Where-Object { $_.Board -eq "Cornerstone" })
$brokerBrreaRows = @($brokerBayRows | Where-Object { $_.Board -eq "BRREA" })

$brokerCaorAccounts = $brokerCaorRows.Count
$brokerBrreaAccounts = $brokerBrreaRows.Count
$brokerCaorUnique = ($brokerCaorRows | Select-Object -ExpandProperty NameKey -Unique).Count
$brokerBrreaUnique = ($brokerBrreaRows | Select-Object -ExpandProperty NameKey -Unique).Count
$brokerCaorDup = $brokerCaorAccounts - $brokerCaorUnique
$brokerBrreaDup = $brokerBrreaAccounts - $brokerBrreaUnique
$brokerTotalAccounts = $brokerCaorAccounts + $brokerBrreaAccounts
$brokerTotalUniqueByBoard = $brokerCaorUnique + $brokerBrreaUnique

$caorNameSet = @{}
$brreaNameSet = @{}
foreach ($row in $brokerCaorRows) {
    $caorNameSet[$row.NameKey] = $true
}
foreach ($row in $brokerBrreaRows) {
    $brreaNameSet[$row.NameKey] = $true
}
$brokerCrossBoardDuplicates = 0
foreach ($nameKey in $caorNameSet.Keys) {
    if ($brreaNameSet.ContainsKey($nameKey)) {
        $brokerCrossBoardDuplicates++
    }
}
$brokerTotalBillableUsers = $brokerTotalUniqueByBoard - $brokerCrossBoardDuplicates

$showingTimeCaorPrefixRows = @(
    $memberRows | Where-Object {
        $_.Vendor -eq "ShowingTime" -and
        $_.Board -eq "Cornerstone" -and
        (
            [string]$_.MemberMlsId -like "WR*" -or
            [string]$_.MemberMlsId -like "CA*" -or
            [string]$_.MemberMlsId -like "KW*"
        )
    }
)
$showingTimeCaorPrefixCount = $showingTimeCaorPrefixRows.Count

$runMonth = Get-Date -Format "MMMM"
$runDay = Get-Date -Format "dd"
$runFolderName = "{0}_{1}_ShowingSystemStats" -f $runMonth, $runDay
$outDir = Join-Path $OutputRoot $runFolderName
$dataDir = Join-Path $outDir "data"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

$officesOut = Join-Path $dataDir "offices_selected.csv"
$membersOut = Join-Path $dataDir "members_detail.csv"
$summaryOut = Join-Path $dataDir "summary.csv"
$duplicatesOut = Join-Path $dataDir "duplicates_by_name.csv"
$templateOut = Join-Path $outDir ("Showing_System_Member_Count_{0}.csv" -f $runMonth)

$officeByKey.Values |
    Sort-Object Board, Vendor, OfficeName |
    Export-Csv -Path $officesOut -NoTypeInformation -Encoding UTF8

$memberRows |
    Sort-Object Board, Vendor, OfficeName, MemberName, MemberKey |
    Export-Csv -Path $membersOut -NoTypeInformation -Encoding UTF8

$summaryRows |
    Sort-Object Board, Vendor |
    Export-Csv -Path $summaryOut -NoTypeInformation -Encoding UTF8

$duplicateRows |
    Sort-Object Board, Vendor, DuplicateName, OfficeName, MemberKey |
    Export-Csv -Path $duplicatesOut -NoTypeInformation -Encoding UTF8

$templateLines = @(
    "BrokerBay,,,",
    'Board,"Number of Broker Bay Users (F1,F2,O1,SP1,SP2,SP3,SP4,SP5)",Duplicates,Actual Total (Minus Duplicates)',
    ("CAOR,{0},{1},{2}" -f $brokerCaorAccounts, $brokerCaorDup, $brokerCaorUnique),
    ("BRREA,{0},{1},{2}" -f $brokerBrreaAccounts, $brokerBrreaDup, $brokerBrreaUnique),
    ("TOTAL,{0},,{1}" -f $brokerTotalAccounts, $brokerTotalUniqueByBoard),
    ("CAOR vs BRREA DUPLICATES,,{0}," -f $brokerCrossBoardDuplicates),
    ("TOTAL BILLABLE USERS,{0},," -f $brokerTotalBillableUsers),
    ",,,",
    ",,,",
    ",,,",
    ",,,",
    ",,,",
    "ShowingTime,,,",
    'Board,"Number of ShowingTime Users (F1,F2,O1,SP1,SP2,SP3,SP4,SP5) AND (WR*,CA*,KW*)",,',
    ("CAOR,{0},," -f $showingTimeCaorPrefixCount)
)

Set-Content -LiteralPath $templateOut -Value $templateLines -Encoding UTF8

Write-Host ""
Write-Host "Summary"
$summaryRows | Sort-Object Board, Vendor | Format-Table -AutoSize

Write-Host ""
Write-Host "Template Report"
Write-Host ("  BrokerBay cross-board duplicates (CAOR vs BRREA): {0}" -f $brokerCrossBoardDuplicates)
Write-Host ("  BrokerBay total billable users: {0}" -f $brokerTotalBillableUsers)
Write-Host ("  ShowingTime CAOR (WR*/CA*/KW*): {0}" -f $showingTimeCaorPrefixCount)

Write-Host ""
Write-Host "Output directory:"
Write-Host "  $outDir"
Write-Host ""
Write-Host "Files:"
Write-Host "  $summaryOut"
Write-Host "  $officesOut"
Write-Host "  $membersOut"
Write-Host "  $duplicatesOut"
Write-Host "  $templateOut"
