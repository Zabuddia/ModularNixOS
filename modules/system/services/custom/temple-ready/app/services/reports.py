def _truthy(v):
    if isinstance(v, bool):
        return v
    if v is None:
        return False
    return str(v).strip().lower() in {"1", "true", "yes", "y"}

def filter_active_with_next(df):
    """Only Active == true and Next Ordinance not blank/NaN. Include Unit."""
    if df is None or "Active" not in df.columns or "Next Ordinance" not in df.columns:
        return []

    # Active mask
    m_active = df["Active"].apply(_truthy)

    # Next Ordinance mask: not NaN, not empty, not "nan"
    nxt = df["Next Ordinance"]
    m_next = nxt.notna() & (nxt.astype(str).str.strip() != "") & (nxt.astype(str).str.lower() != "nan")

    filtered = df[m_active & m_next].copy()

    # Normalize columns we need
    for col in ("Name", "Unit", "Age", "Gender", "Next Ordinance"):
        if col not in filtered.columns:
            filtered[col] = ""
    filtered["Next Ordinance"] = filtered["Next Ordinance"].where(filtered["Next Ordinance"].notna(), "")

    # Rename for template and select columns (now includes Unit)
    filtered = filtered[["Name", "Unit", "Age", "Gender", "Next Ordinance"]].rename(
        columns={"Next Ordinance": "NextOrdinance"}
    )
    return filtered.to_dict(orient="records")

def filter_completed(df):
    """
    Return rows where ANY completion flag is true, regardless of Active status
    or Next Ordinance. Include Unit. Uses the new 'Received ... Priesthood' flags.
    """
    if df is None:
        return []

    # Ensure all flag columns exist (source column names from your DataFrame)
    flags_src = [
        "Received Aaronic Priesthood",
        "Received Melchizedek Priesthood",
        "Endowment Date Changed",
        "Marriage Date Changed",
        "Is Sealed to a Spouse Changed",
        "Was Baptized Recently",
    ]
    for f in flags_src:
        if f not in df.columns:
            df[f] = False

    # Create mask: any flag true
    mask = df[flags_src].map(_truthy).any(axis=1)

    filtered = df[mask].copy()

    # Normalize essentials
    for col in ("Name", "Unit", "Age", "Gender"):
        if col not in filtered.columns:
            filtered[col] = ""

    # Normalize flags into template-friendly keys (no spaces)
    rename_map = {
        "Received Aaronic Priesthood": "ReceivedAaronicPriesthood",
        "Received Melchizedek Priesthood": "ReceivedMelchizedekPriesthood",
        "Endowment Date Changed": "EndowmentDateChanged",
        "Marriage Date Changed": "MarriageDateChanged",
        "Is Sealed to a Spouse Changed": "IsSealedToSpouseChanged",
        "Was Baptized Recently": "WasBaptizedRecently",
    }
    for src, dst in rename_map.items():
        filtered[dst] = filtered[src].apply(_truthy)

    out_cols = ["Name", "Unit", "Age", "Gender"] + list(rename_map.values())
    return filtered[out_cols].to_dict(orient="records")