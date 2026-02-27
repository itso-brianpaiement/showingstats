#!/usr/bin/env python3
import argparse
import csv
import datetime
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from collections import defaultdict


def read_key_value_file(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Keys file not found: {path}")

    data = {}
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or ":" not in line:
                continue
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()
            if key:
                data[key] = value
    return data


def fetch_paged(start_url, entity_name, max_pages=5000):
    rows = []
    url = start_url
    page = 0
    while url:
        page += 1
        if page > max_pages:
            raise RuntimeError(f"Exceeded max pages ({max_pages}) for {entity_name}")
        with urllib.request.urlopen(url, timeout=120) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
        rows.extend(payload.get("value", []))
        url = payload.get("@odata.nextLink")
    return rows


def normalize_board(office):
    candidates = [
        str(office.get("OriginatingSystemName") or ""),
        str(office.get("OfficeAOR") or ""),
    ]
    for raw in candidates:
        if not raw:
            continue
        u = raw.strip().upper()
        if u == "CAOR" or "CORNERSTONE" in u:
            return "Cornerstone"
        if u == "BRREA" or "BRANTFORD" in u:
            return "BRREA"
    return None


def normalize_vendor(showing_system):
    if not showing_system:
        return None
    u = str(showing_system).strip().upper()
    if u in ("BRBY", "BROKERBAY") or "BROKERBAY" in u:
        return "BrokerBay"
    if u in ("SA", "SHOWINGTIME") or "SHOWINGTIME" in u:
        return "ShowingTime"
    return None


def normalize_text(text):
    if not text:
        return ""
    t = str(text).upper()
    t = re.sub(r"[^A-Z0-9 ]", " ", t)
    t = re.sub(r"\s+", " ", t)
    return t.strip()


def get_name_key(member):
    first = normalize_text(member.get("MemberFirstName", ""))
    last = normalize_text(member.get("MemberLastName", ""))
    full = normalize_text(member.get("MemberFullName", ""))
    if last or first:
        return f"{last}|{first}"
    if full:
        return full
    return f"NO_NAME|{member.get('MemberKey', '')}"


def get_display_name(member):
    first = str(member.get("MemberFirstName") or "").strip()
    last = str(member.get("MemberLastName") or "").strip()
    full = str(member.get("MemberFullName") or "").strip()
    parts = [p for p in (first, last) if p]
    if parts:
        return " ".join(parts)
    if full:
        return full
    return str(member.get("MemberKey") or "")


def write_csv(path, fieldnames, rows):
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def sort_rows(rows, keys):
    return sorted(rows, key=lambda r: tuple((r.get(k) or "") for k in keys))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--keys-file", default="")
    parser.add_argument("--output-root", default=os.path.join(os.path.dirname(__file__), "output"))
    parser.add_argument("--top", type=int, default=200)
    args = parser.parse_args()

    if args.top < 1 or args.top > 200:
        raise ValueError("Top must be between 1 and 200 (Bridge limit).")

    if args.keys_file:
        keys_file = args.keys_file
    else:
        candidates = [
            os.path.join(os.path.dirname(__file__), "keys"),
            os.path.join(os.path.dirname(__file__), "keys.txt"),
        ]
        keys_file = next((p for p in candidates if os.path.exists(p)), candidates[0])

    config = read_key_value_file(keys_file)
    endpoint_value = str(config.get("Endpoint URL") or "").strip().rstrip("/")
    server_token = str(config.get("Server Token") or "").strip()

    if not endpoint_value:
        raise ValueError("Endpoint URL missing in keys file.")
    if not server_token:
        raise ValueError("Server Token missing in keys file.")

    bridge_base_odata_url = "https://api.bridgedataoutput.com/api/v2/OData"
    if endpoint_value.lower().startswith("http://") or endpoint_value.lower().startswith("https://"):
        safe_endpoint = endpoint_value
    else:
        dataset_code = endpoint_value.strip("/").strip()
        if not dataset_code:
            raise ValueError("Endpoint URL value is blank. Use dataset code like 'itso'.")
        safe_endpoint = f"{bridge_base_odata_url}/{dataset_code}"

    print("Pulling offices...")

    office_filter = " and ".join([
        "(OfficeStatus eq 'A' or OfficeStatus eq 'Active')",
        "(OriginatingSystemName eq 'CAOR' or OriginatingSystemName eq 'Cornerstone' or OriginatingSystemName eq 'BRREA' or OriginatingSystemName eq 'Brantford')",
        "(ITSO_ShowingSystem eq 'BRBY' or ITSO_ShowingSystem eq 'SA' or ITSO_ShowingSystem eq 'BrokerBay' or ITSO_ShowingSystem eq 'ShowingTime')",
    ])
    office_select = "OfficeKey,OfficeName,OfficeMlsId,OfficeStatus,OriginatingSystemName,OfficeAOR,ITSO_ShowingSystem"
    office_url = (
        f"{safe_endpoint}/Office?"
        f"$filter={urllib.parse.quote(office_filter, safe='')}"
        f"&$select={office_select}"
        f"&$top={args.top}"
        f"&access_token={urllib.parse.quote(server_token, safe='')}"
    )

    raw_offices = fetch_paged(office_url, "Office")
    office_by_key = {}
    for office in raw_offices:
        office_key = str(office.get("OfficeKey") or "")
        if not office_key:
            continue
        board = normalize_board(office)
        vendor = normalize_vendor(office.get("ITSO_ShowingSystem"))
        if not board or not vendor:
            continue
        if office_key not in office_by_key:
            office_by_key[office_key] = {
                "OfficeKey": office_key,
                "OfficeName": str(office.get("OfficeName") or ""),
                "OfficeMlsId": str(office.get("OfficeMlsId") or ""),
                "OriginatingSystemName": str(office.get("OriginatingSystemName") or ""),
                "OfficeAOR": str(office.get("OfficeAOR") or ""),
                "ShowingSystemRaw": str(office.get("ITSO_ShowingSystem") or ""),
                "Vendor": vendor,
                "Board": board,
            }

    print(f"Selected offices after board/vendor mapping: {len(office_by_key)}")
    if not office_by_key:
        raise RuntimeError("No offices found for the configured criteria.")

    print("Pulling members...")

    security_clauses = [
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
        "startswith(MemberMlsSecurityClass,'SP5')",
    ]
    member_filter = f"(MemberStatus eq 'A' or MemberStatus eq 'Active') and ({' or '.join(security_clauses)})"
    member_select = "MemberKey,MemberFirstName,MemberLastName,MemberFullName,MemberStatus,MemberMlsSecurityClass,OfficeKey,MemberEmail,MemberMlsId"
    member_url = (
        f"{safe_endpoint}/Member?"
        f"$filter={urllib.parse.quote(member_filter, safe='')}"
        f"&$select={member_select}"
        f"&$top={args.top}"
        f"&access_token={urllib.parse.quote(server_token, safe='')}"
    )

    raw_members = fetch_paged(member_url, "Member")
    print(f"Members returned from API filter: {len(raw_members)}")

    member_rows = []
    seen_member_office = set()
    for member in raw_members:
        office_key = str(member.get("OfficeKey") or "")
        if office_key not in office_by_key:
            continue
        member_key = str(member.get("MemberKey") or "")
        if not member_key:
            continue
        dedupe_account_key = f"{member_key}|{office_key}"
        if dedupe_account_key in seen_member_office:
            continue
        seen_member_office.add(dedupe_account_key)

        office = office_by_key[office_key]
        member_rows.append({
            "Board": office["Board"],
            "Vendor": office["Vendor"],
            "OfficeKey": office["OfficeKey"],
            "OfficeName": office["OfficeName"],
            "OfficeMlsId": office["OfficeMlsId"],
            "OriginatingSystemName": office["OriginatingSystemName"],
            "OfficeAOR": office["OfficeAOR"],
            "MemberKey": member_key,
            "MemberName": get_display_name(member),
            "MemberEmail": str(member.get("MemberEmail") or ""),
            "MemberMlsId": str(member.get("MemberMlsId") or ""),
            "MemberStatus": str(member.get("MemberStatus") or ""),
            "MemberMlsSecurityClass": str(member.get("MemberMlsSecurityClass") or ""),
            "NameKey": get_name_key(member),
        })

    print(f"Members linked to selected offices: {len(member_rows)}")

    office_group_counts = defaultdict(int)
    for office in office_by_key.values():
        office_group_counts[(office["Board"], office["Vendor"])] += 1

    member_group_map = defaultdict(list)
    for row in member_rows:
        member_group_map[(row["Board"], row["Vendor"])].append(row)

    summary_rows = []
    duplicate_rows = []
    for board_vendor in sorted(office_group_counts.keys()):
        board, vendor = board_vendor
        rows = member_group_map.get(board_vendor, [])
        office_count = office_group_counts[board_vendor]
        account_count = len(rows)
        unique_people_count = len({r["NameKey"] for r in rows}) if rows else 0
        duplicate_account_count = account_count - unique_people_count
        summary_rows.append({
            "Board": board,
            "Vendor": vendor,
            "OfficeCount": office_count,
            "MemberAccountCount": account_count,
            "UniquePeopleByNameCount": unique_people_count,
            "DuplicateAccountCountByName": duplicate_account_count,
        })

        grouped = defaultdict(list)
        for r in rows:
            grouped[r["NameKey"]].append(r)
        for name_key, group in grouped.items():
            if len(group) <= 1:
                continue
            for r in group:
                duplicate_rows.append({
                    "Board": r["Board"],
                    "Vendor": r["Vendor"],
                    "DuplicateName": r["MemberName"],
                    "DuplicateNameKey": name_key,
                    "DuplicateCountByName": len(group),
                    "MemberKey": r["MemberKey"],
                    "OfficeKey": r["OfficeKey"],
                    "OfficeName": r["OfficeName"],
                    "MemberEmail": r["MemberEmail"],
                    "MemberStatus": r["MemberStatus"],
                    "MemberMlsSecurityClass": r["MemberMlsSecurityClass"],
                })

    broker_bay_rows = [r for r in member_rows if r["Vendor"] == "BrokerBay"]
    broker_caor_rows = [r for r in broker_bay_rows if r["Board"] == "Cornerstone"]
    broker_brrea_rows = [r for r in broker_bay_rows if r["Board"] == "BRREA"]

    broker_caor_accounts = len(broker_caor_rows)
    broker_brrea_accounts = len(broker_brrea_rows)
    broker_caor_unique = len({r["NameKey"] for r in broker_caor_rows})
    broker_brrea_unique = len({r["NameKey"] for r in broker_brrea_rows})
    broker_caor_dup = broker_caor_accounts - broker_caor_unique
    broker_brrea_dup = broker_brrea_accounts - broker_brrea_unique
    broker_total_accounts = broker_caor_accounts + broker_brrea_accounts
    broker_total_unique_by_board = broker_caor_unique + broker_brrea_unique
    broker_cross_board_duplicates = len({r["NameKey"] for r in broker_caor_rows} & {r["NameKey"] for r in broker_brrea_rows})
    broker_total_billable_users = broker_total_unique_by_board - broker_cross_board_duplicates

    showing_time_caor_prefix_count = len([
        r for r in member_rows
        if r["Vendor"] == "ShowingTime"
        and r["Board"] == "Cornerstone"
        and (r["MemberMlsId"].startswith("WR") or r["MemberMlsId"].startswith("CA") or r["MemberMlsId"].startswith("KW"))
    ])

    now = datetime.datetime.now()
    run_month = now.strftime("%B")
    run_day = now.strftime("%d")
    run_folder_name = f"{run_month}_{run_day}_ShowingSystemStats"
    out_dir = os.path.join(args.output_root, run_folder_name)
    data_dir = os.path.join(out_dir, "data")
    os.makedirs(data_dir, exist_ok=True)

    offices_out = os.path.join(data_dir, "offices_selected.csv")
    members_out = os.path.join(data_dir, "members_detail.csv")
    summary_out = os.path.join(data_dir, "summary.csv")
    duplicates_out = os.path.join(data_dir, "duplicates_by_name.csv")
    template_out = os.path.join(out_dir, f"Showing_System_Member_Count_{run_month}.csv")

    office_rows = sort_rows(list(office_by_key.values()), ["Board", "Vendor", "OfficeName"])
    member_rows_sorted = sort_rows(member_rows, ["Board", "Vendor", "OfficeName", "MemberName", "MemberKey"])
    summary_rows_sorted = sort_rows(summary_rows, ["Board", "Vendor"])
    duplicate_rows_sorted = sort_rows(duplicate_rows, ["Board", "Vendor", "DuplicateName", "OfficeName", "MemberKey"])

    write_csv(
        offices_out,
        ["OfficeKey", "OfficeName", "OfficeMlsId", "OriginatingSystemName", "OfficeAOR", "ShowingSystemRaw", "Vendor", "Board"],
        office_rows,
    )
    write_csv(
        members_out,
        ["Board", "Vendor", "OfficeKey", "OfficeName", "OfficeMlsId", "OriginatingSystemName", "OfficeAOR", "MemberKey", "MemberName", "MemberEmail", "MemberMlsId", "MemberStatus", "MemberMlsSecurityClass", "NameKey"],
        member_rows_sorted,
    )
    write_csv(
        summary_out,
        ["Board", "Vendor", "OfficeCount", "MemberAccountCount", "UniquePeopleByNameCount", "DuplicateAccountCountByName"],
        summary_rows_sorted,
    )
    write_csv(
        duplicates_out,
        ["Board", "Vendor", "DuplicateName", "DuplicateNameKey", "DuplicateCountByName", "MemberKey", "OfficeKey", "OfficeName", "MemberEmail", "MemberStatus", "MemberMlsSecurityClass"],
        duplicate_rows_sorted,
    )

    template_lines = [
        "BrokerBay,,,",
        'Board,"Number of Broker Bay Users (F1,F2,O1,SP1,SP2,SP3,SP4,SP5)",Duplicates,Actual Total (Minus Duplicates)',
        f"CAOR,{broker_caor_accounts},{broker_caor_dup},{broker_caor_unique}",
        f"BRREA,{broker_brrea_accounts},{broker_brrea_dup},{broker_brrea_unique}",
        f"TOTAL,{broker_total_accounts},,{broker_total_unique_by_board}",
        f"CAOR vs BRREA DUPLICATES,,{broker_cross_board_duplicates},",
        f"TOTAL BILLABLE USERS,{broker_total_billable_users},,",
        ",,,",
        ",,,",
        ",,,",
        ",,,",
        ",,,",
        "ShowingTime,,,",
        'Board,"Number of ShowingTime Users (F1,F2,O1,SP1,SP2,SP3,SP4,SP5) AND (WR*,CA*,KW*)",,',
        f"CAOR,{showing_time_caor_prefix_count},,",
    ]
    with open(template_out, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(template_lines) + "\n")

    print("")
    print("Summary")
    for s in summary_rows_sorted:
        print(
            f"  {s['Board']} | {s['Vendor']} | offices={s['OfficeCount']} | "
            f"accounts={s['MemberAccountCount']} | unique={s['UniquePeopleByNameCount']} | "
            f"dups={s['DuplicateAccountCountByName']}"
        )

    print("")
    print("Template Report")
    print(f"  BrokerBay cross-board duplicates (CAOR vs BRREA): {broker_cross_board_duplicates}")
    print(f"  BrokerBay total billable users: {broker_total_billable_users}")
    print(f"  ShowingTime CAOR (WR*/CA*/KW*): {showing_time_caor_prefix_count}")

    print("")
    print("Output directory:")
    print(f"  {out_dir}")
    print("")
    print("Files:")
    print(f"  {summary_out}")
    print(f"  {offices_out}")
    print(f"  {members_out}")
    print(f"  {duplicates_out}")
    print(f"  {template_out}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
