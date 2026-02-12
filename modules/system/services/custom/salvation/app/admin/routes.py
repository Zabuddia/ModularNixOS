from io import BytesIO
from functools import wraps
from sqlalchemy import func

from flask import (
    render_template,
    abort,
    request,
    redirect,
    url_for,
    flash,
    send_file,
)
from flask_login import login_required, current_user
from urllib.parse import unquote
import io
import os
import re
import unicodedata

from . import admin_bp
from ..models import db, Document, CsvArtifact

from app.services.dashboard import latest_df, units_from_df

# --- Admin gate --------------------------------------------------------------

def admin_required(view_func):
    @wraps(view_func)
    @login_required
    def wrapper(*args, **kwargs):
        if not current_user.is_admin():
            abort(403)
        return view_func(*args, **kwargs)
    return wrapper

# --- Table / pandas helpers --------------------------------------------------
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pandas as pd


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    if df is None or df.empty:
        return df
    df = df.copy()
    df.columns = [str(c).replace("\r", " ").replace("\n", " ").strip() for c in df.columns]
    df = df.rename(columns={"Preferred Name": "Name", "Current Unit": "Unit"})
    df = df.dropna(how="all")
    df = df.loc[:, ~df.columns.duplicated()]
    return df


def fix_mojibake(x):
    """Fix common UTF-8 text mistakenly decoded as latin1."""
    if isinstance(x, str):
        try:
            return x.encode("latin1").decode("utf-8")
        except UnicodeError:
            return x
    return x


def dedupe_concatenated_header(s: str) -> str:
    """Collapse duplicated concatenated headers, e.g., NameName -> Name."""
    s = str(s).strip()

    if len(s) % 2 == 0:
        half = len(s) // 2
        if s[:half] == s[half:]:
            return s[:half].strip()

    m = re.fullmatch(r"(.+)\1", s)
    if m:
        return m.group(1).strip()

    return s


def strip_label_prefix(value: str, col_name: str) -> str:
    """Remove repeated column label prefixes from cell values."""
    if not isinstance(value, str):
        return value

    v = fix_mojibake(value).strip()
    c = fix_mojibake(col_name).strip()
    if not c:
        return v

    col_esc = re.escape(c)
    v = re.sub(rf"^(?:{col_esc}\s*)+", "", v)
    v = re.sub(rf"^(?:{col_esc})+", "", v)
    v = v.strip()
    return "" if v == "" else v


def html_table_to_clean_dataframe(html_table: str) -> pd.DataFrame:
    """Parse the first HTML table and return a cleaned DataFrame."""
    tables = pd.read_html(io.StringIO(html_table))
    if not tables:
        raise ValueError("No HTML <table> was found in the pasted content.")

    df = tables[0]

    for col in df.columns:
        df[col] = df[col].map(fix_mojibake)

    df.columns = [dedupe_concatenated_header(fix_mojibake(c)) for c in df.columns]

    for col in df.columns:
        df[col] = df[col].map(lambda v, c=col: strip_label_prefix(v, c))

    return clean_dataframe(df)


def sanitize_csv_filename(name: str) -> str:
    base = (name or "").strip()
    base = base.replace("\\", "/").split("/")[-1]
    base = unicodedata.normalize("NFKD", base).encode("ascii", "ignore").decode("ascii")
    base = base.replace(" ", "_")
    base = re.sub(r"[^A-Za-z0-9._-]", "_", base).lstrip(".-")
    if not base:
        base = "output"
    if not base.lower().endswith(".csv"):
        base += ".csv"
    return base


def collapse_duplicate_columns(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    for c in list(out.columns):
        if c.endswith("_dup"):
            base = c[:-4]
            if base in out.columns:
                out[base] = out[base].combine_first(out[c])
                out.drop(columns=[c], inplace=True)
    return out


def merge_dfs_on_name_age(dfs: list[pd.DataFrame]) -> pd.DataFrame:
    if not dfs:
        return pd.DataFrame()
    norm = []
    for i, d in enumerate(dfs):
        d = d.copy()
        d.columns = [c.strip() for c in d.columns]
        if "Name" not in d.columns:
            if "Preferred Name" in d.columns:
                d = d.rename(columns={"Preferred Name": "Name"})
            else:
                raise ValueError(f"Missing 'Name' column in table {i}")
        if "Age" not in d.columns:
            raise ValueError(f"Missing 'Age' column in table {i}")
        norm.append(d)
    merged = norm[0]
    for d in norm[1:]:
        merged = pd.merge(merged, d, on=["Name", "Age"], how="outer", suffixes=("", "_dup"))
        merged = collapse_duplicate_columns(merged)
    return merged

# --- Next ordinance helpers --------------------------------------------------
def _has_value(v):
    return v is not None and str(v).strip() != ""

def _compute_next_ordinance(age: int | None,
                            gender_up: str,
                            priest_low: str,
                            baptism_date_str: str,
                            endowment_date_str: str,
                            sealed_low: str,
                            marriage_date_str: str) -> str | None:
    """Return one of the required labels or None, honoring precedence."""
    baptized = _has_value(baptism_date_str)
    endowment_has_date = _has_value(endowment_date_str)
    married = _has_value(marriage_date_str)
    # Treat blank or "no" as not sealed to current spouse
    not_sealed_or_blank = (sealed_low == "" or sealed_low == "no")

    # 1) Baptism (takes precedence over all)
    if not baptized:
        return "Baptism"

    # 2) Aaronic Priesthood Ordination (takes precedence over Endowment/Sealing)
    if (
        gender_up == "M" and age is not None and age >= 12 and
        (priest_low == "" or priest_low == "unordained")
    ):
        return "Aaronic Priesthood Ordination"

    # 3) Melchizedek Priesthood Ordination (takes precedence over Endowment/Sealing)
    if (
        gender_up == "M" and age is not None and age >= 18 and
        priest_low == "aaronic"
    ):
        return "Melchizedek Priesthood Ordination"

    # 4) Endowment
    if age is not None and age >= 18 and not endowment_has_date:
        return "Endowment"

    # 5) Sealing
    if age is not None and age >= 18 and endowment_has_date and not_sealed_or_blank and married:
        return "Sealing"

    return None

# --- Diff helpers (CSV -> DataFrame) -----------------------------------------

def _values_different(v1, v2):
    if pd.isna(v1) and pd.isna(v2):
        return False
    s1 = "" if pd.isna(v1) else str(v1).strip()
    s2 = "" if pd.isna(v2) else str(v2).strip()
    return s1 != s2


def _became_filled(old, new):
    old_blank = pd.isna(old) or str(old).strip() == ""
    new_filled = not pd.isna(new) and str(new).strip() != ""
    return old_blank and new_filled


def _parse_date(val):
    ts = pd.to_datetime(val, errors="coerce")
    if isinstance(ts, pd.Timestamp):
        try:
            ts = ts.tz_localize(None)  # drop tz if present
        except TypeError:
            pass  # already naive
    return ts  # may be NaT if parse failed

def _to_bool(v):
    if isinstance(v, bool):
        return v
    s = str(v).strip().lower()
    return s in ("true", "1", "yes", "y", "t")

def inherit_active_from_baseline(df_current: pd.DataFrame, df_prev: pd.DataFrame | None) -> pd.DataFrame:
    out = df_current.copy()

    # Ensure the column exists, default False
    if "Active" not in out.columns:
        out.insert(len(out.columns), "Active", False)

    # No baseline or baseline lacks Active -> keep defaults
    if df_prev is None or "Active" not in df_prev.columns:
        return out

    # Normalize keys in baseline
    prev = df_prev.copy()
    prev.columns = prev.columns.str.strip()
    prev["_name_key"] = prev["Name"].astype(str).str.strip().str.lower()
    prev["_age_key"]  = pd.to_numeric(prev.get("Age"), errors="coerce")
    if "Unit" in prev.columns:
        prev["_unit_key"] = prev["Unit"].astype(str).str.strip()
    else:
        prev["_unit_key"] = ""

    # Build lookup: (name_key, age, unit) -> bool
    lookup = {}
    for _, row in prev.iterrows():
        nk = row["_name_key"]
        ak = row["_age_key"]
        uk = row["_unit_key"]
        if pd.isna(ak):
            continue
        ak = int(ak)
        val = _to_bool(row.get("Active"))
        lookup[(nk, ak, uk)] = val
        # birthday tolerance (previous age +/- 1)
        lookup[(nk, ak + 1, uk)] = val

    # Normalize keys in current
    out["_name_key"] = out["Name"].astype(str).str.strip().str.lower()
    out["_age_key"]  = pd.to_numeric(out.get("Age"), errors="coerce")
    if "Unit" in out.columns:
        out["_unit_key"] = out["Unit"].astype(str).str.strip()
    else:
        out["_unit_key"] = ""

    # Fill from lookup, keep default False if no match
    for idx, row in out.iterrows():
        nk = row["_name_key"]
        ak = row["_age_key"]
        uk = row["_unit_key"]
        if pd.isna(ak):
            continue
        ak = int(ak)
        val = lookup.get((nk, ak, uk))
        if val is None:
            # also try previous age (current-1) in case current just had a birthday
            val = lookup.get((nk, ak - 1, uk))
        if val is not None:
            out.at[idx, "Active"] = bool(val)

    # drop helper cols
    out.drop(columns=[c for c in ["_name_key","_age_key","_unit_key"] if c in out.columns], inplace=True)
    return out

def build_processed_dataframe(df_current: pd.DataFrame, df_previous: pd.DataFrame | None) -> pd.DataFrame:
    cur = df_current.copy()
    cur.columns = cur.columns.str.strip()
    cur["_name_key"] = cur["Name"].astype(str).str.strip().str.lower()
    cur["_age_key"] = pd.to_numeric(cur["Age"], errors="coerce")

    prev_lookup = {}
    if df_previous is not None and not df_previous.empty:
        prev = df_previous.copy()
        prev.columns = prev.columns.str.strip()
        prev["_name_key"] = prev["Name"].astype(str).str.strip().str.lower()
        prev["_age_key"] = pd.to_numeric(prev["Age"], errors="coerce")
        for _, row in prev.iterrows():
            nk = row["_name_key"]
            ak = row["_age_key"]
            if pd.isna(ak):
                continue
            ak = int(ak)
            prev_lookup[(nk, ak)] = row
            prev_lookup[(nk, ak + 1)] = row  # birthday tolerance

    six_months_ago = pd.Timestamp.now(tz=None) - pd.Timedelta(days=180)
    out_rows = []

    for _, r in cur.iterrows():
        nk = r["_name_key"]
        ak = r["_age_key"]

        match = None
        if ak is not None and not pd.isna(ak):
            ak = int(ak)
            match = prev_lookup.get((nk, ak))
            if match is None:
                match = prev_lookup.get((nk, ak - 1))

        row = r.drop(labels=[c for c in r.index if c.startswith("_")], errors="ignore").to_dict()

        flags = {
            "Priesthood Changed": False,
            "Received Aaronic Priesthood": False,
            "Received Melchizedek Priesthood": False,
            "Endowment Date Changed": False,
            "Marriage Date Changed": False,
            "Is Sealed to a Spouse Changed": False,
            "Temple Recommend Became Filled": False,
            "New Move In": match is None,
            "Was Baptized Recently": False,
            "Needs Deacon Ordination": False,
            "Needs Melchizedek Ordination": False,
            "Needs Endowment": False,
            "Has Recommend but No Endowment": False,
            "Married Not Sealed": False,
            "Married Not Sealed but Endowed": False,
        }

        if match is not None:
            flags["Priesthood Changed"] = _values_different(match.get("Priesthood"), r.get("Priesthood"))
            flags["Endowment Date Changed"] = _values_different(match.get("Endowment Date"), r.get("Endowment Date"))
            flags["Marriage Date Changed"] = _values_different(match.get("Marriage Date"), r.get("Marriage Date"))
            old_sealed = "" if pd.isna(match.get("Is Sealed to a Spouse")) else str(
                match.get("Is Sealed to a Spouse")
            ).strip().lower()
            new_sealed = "" if pd.isna(r.get("Is Sealed to a Spouse")) else str(
                r.get("Is Sealed to a Spouse")
            ).strip().lower()
            flags["Is Sealed to a Spouse Changed"] = ((old_sealed == "yes") != (new_sealed == "yes"))
            flags["Temple Recommend Became Filled"] = _became_filled(
                match.get("Temple Recommend Status"), r.get("Temple Recommend Status")
            )
        else:
            bd = _parse_date(r.get("Baptism Date"))
            if pd.notna(bd) and bd > six_months_ago:
                flags["Was Baptized Recently"] = True

        # normalize for logic
        try:
            age = int(float(r.get("Age")))
        except Exception:
            age = None
        gender = "" if pd.isna(r.get("Gender")) else str(r.get("Gender")).strip().upper()
        priest = "" if pd.isna(r.get("Priesthood")) else str(r.get("Priesthood")).strip().lower()
        endow = "" if pd.isna(r.get("Endowment Date")) else str(r.get("Endowment Date")).strip()
        rec = "" if pd.isna(r.get("Temple Recommend Status")) else str(r.get("Temple Recommend Status")).strip()
        marr = "" if pd.isna(r.get("Marriage Date")) else str(r.get("Marriage Date")).strip()
        sealed = "" if pd.isna(r.get("Is Sealed to a Spouse")) else str(
            r.get("Is Sealed to a Spouse")
        ).strip().lower()
        baptism = "" if pd.isna(r.get("Baptism Date")) else str(r.get("Baptism Date")).strip()

        if flags["Priesthood Changed"]:
            if priest == "melchizedek":
                flags["Received Melchizedek Priesthood"] = True
            elif priest == "aaronic":
                flags["Received Aaronic Priesthood"] = True

        if age is not None:
            flags["Needs Deacon Ordination"] = (gender == "M" and (priest in ["", "unordained"]) and age >= 12)
            flags["Needs Melchizedek Ordination"] = (gender == "M" and priest == "aaronic" and age >= 18)
            flags["Needs Endowment"] = (endow == "" and age >= 18)
            flags["Has Recommend but No Endowment"] = (endow == "" and rec != "" and age >= 18)

        flags["Married Not Sealed"] = (marr != "" and sealed != "yes")
        flags["Married Not Sealed but Endowed"] = (marr != "" and sealed != "yes" and endow != "")

        next_ord = _compute_next_ordinance(
            age=age,
            gender_up=gender,
            priest_low=priest,
            baptism_date_str=baptism,
            endowment_date_str=endow,
            sealed_low=sealed,
            marriage_date_str=marr,
        )
        row["Next Ordinance"] = next_ord

        row.update(flags)
        out_rows.append(row)

    return pd.DataFrame(out_rows)

# --- Routes ------------------------------------------------------------------

@admin_bp.route("/dashboard")
@admin_required
def dashboard():
    df = latest_df()
    units = units_from_df(df)
    return render_template("admin_dashboard.html", units=units)

def _upload_page_context() -> dict:
    csvs = CsvArtifact.query.order_by(CsvArtifact.sort_order.desc(), CsvArtifact.generated_at.desc()).all()
    baselines = [c for c in csvs if (c.filename or "").lower().endswith(".csv")]
    return {"csvs": csvs, "baselines": baselines}


@admin_bp.route("/upload", methods=["GET"])
@admin_required
def upload():
    """Show direct HTML-table -> CSV generation tools."""
    return render_template("admin_upload.html", **_upload_page_context())

@admin_bp.route("/process-tables", methods=["POST"])
@admin_bp.route("/process-pdfs", methods=["POST"])
@admin_required
def process_tables():
    html_table = (request.form.get("html_table") or "").strip()
    selected_name = (request.form.get("csv_filename") or "").strip()
    selected_baseline_id = request.form.get("baseline_id") or ""
    page_ctx = _upload_page_context()

    if not html_table:
        flash("Please paste HTML table content first.", "error")
        return render_template(
            "admin_upload.html",
            pasted_html=html_table,
            selected_filename=selected_name,
            selected_baseline_id=selected_baseline_id,
            **page_ctx,
        )

    # --- Baseline selection (CSV preferred; XLSX supported) ---
    baseline_id = selected_baseline_id
    prev_df = None
    baseline_label = "none"

    if baseline_id:
        try:
            base = CsvArtifact.query.get(int(baseline_id))
        except ValueError:
            base = None
        if not base:
            flash("Selected baseline not found.", "error")
            return render_template(
                "admin_upload.html",
                pasted_html=html_table,
                selected_filename=selected_name,
                selected_baseline_id=selected_baseline_id,
                **page_ctx,
            )

        buf = BytesIO(base.data)
        try:
            if (base.filename or "").lower().endswith(".xlsx"):
                prev_df = pd.read_excel(buf, sheet_name="All")
            else:
                prev_df = pd.read_csv(buf)
            baseline_label = f"{base.filename} (id={base.id})"
        except Exception:
            prev_df = None
            baseline_label = f"{base.filename} (id={base.id}) [unreadable]"
    else:
        latest = (CsvArtifact.query.order_by(CsvArtifact.sort_order.desc(), CsvArtifact.generated_at.desc()).first())
        if latest:
            buf = BytesIO(latest.data)
            try:
                if (latest.filename or "").lower().endswith(".xlsx"):
                    prev_df = pd.read_excel(buf, sheet_name="All")
                else:
                    prev_df = pd.read_csv(buf)
                baseline_label = f"{latest.filename} (id={latest.id})"
            except Exception:
                prev_df = None
                baseline_label = f"{latest.filename} (id={latest.id}) [unreadable]"

    # 1) Parse the pasted HTML table
    try:
        cleaned = html_table_to_clean_dataframe(html_table)
    except ValueError as e:
        flash(str(e), "error")
        return render_template(
            "admin_upload.html",
            pasted_html=html_table,
            selected_filename=selected_name,
            selected_baseline_id=selected_baseline_id,
            **page_ctx,
        )
    except Exception:
        flash("Could not parse that HTML. Paste a valid <table> block and try again.", "error")
        return render_template(
            "admin_upload.html",
            pasted_html=html_table,
            selected_filename=selected_name,
            selected_baseline_id=selected_baseline_id,
            **page_ctx,
        )

    if cleaned is None or cleaned.empty:
        flash("No tabular data found in the pasted HTML table.", "error")
        return render_template(
            "admin_upload.html",
            pasted_html=html_table,
            selected_filename=selected_name,
            selected_baseline_id=selected_baseline_id,
            **page_ctx,
        )

    # 2) Validate/normalize by passing through the merge routine
    try:
        merged = merge_dfs_on_name_age([cleaned])
    except Exception as e:
        flash(f"Failed to merge tables: {e}", "error")
        return render_template(
            "admin_upload.html",
            pasted_html=html_table,
            selected_filename=selected_name,
            selected_baseline_id=selected_baseline_id,
            **page_ctx,
        )

    # 3) Build processed DataFrame with flags (using selected/auto baseline)
    df_out = build_processed_dataframe(merged, prev_df)
    df_out = inherit_active_from_baseline(df_out, prev_df)

    # 4) Determine filename (user-specified, sanitized, ensure .csv)
    ts = datetime.now(ZoneInfo("America/New_York")).strftime("%Y%m%d_%H%M%S")
    user_name = selected_name
    if user_name:
        fname_csv = sanitize_csv_filename(user_name)
    else:
        fname_csv = f"records_{ts}.csv"

    csv_bytes = df_out.to_csv(index=False).encode("utf-8")

    max_order = db.session.query(func.coalesce(func.max(CsvArtifact.sort_order), 0)).scalar()
    next_order = max_order + 1

    try:
        db.session.add(CsvArtifact(
            filename=fname_csv,
            data=csv_bytes,
            note=f"compared to: {baseline_label}",
            sort_order=next_order,
        ))
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        flash(f"Failed to save CSV: {e}", "error")
        return render_template(
            "admin_upload.html",
            pasted_html=html_table,
            selected_filename=selected_name,
            selected_baseline_id=selected_baseline_id,
            **page_ctx,
        )

    flash(f"Built CSV '{fname_csv}' from pasted HTML table.", "success")

    return redirect(url_for("admin.upload"))

@admin_bp.route("/download-csv/<int:csv_id>")
@admin_required
def download_csv(csv_id: int):
    artifact = CsvArtifact.query.get_or_404(csv_id)
    fname = artifact.filename or "file"
    # Support legacy xlsx artifacts (if any exist) while you're transitioning
    if fname.lower().endswith(".xlsx"):
        mtype = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    else:
        mtype = "text/csv"
    return send_file(BytesIO(artifact.data), mimetype=mtype, as_attachment=True, download_name=fname)

@admin_bp.route("/stake/download")
@admin_required
def download_stake_csv():
    df = latest_df()
    if df is None:
        flash("No CSV data available.", "error")
        return redirect(url_for("reports.stake_overview"))

    buf = io.StringIO()
    df.to_csv(buf, index=False)
    buf.seek(0)
    return send_file(
        io.BytesIO(buf.getvalue().encode("utf-8")),
        mimetype="text/csv",
        as_attachment=True,
        download_name="stake_latest.csv"
    )

@admin_bp.route("/units/<path:unit>/download")
@admin_required
def download_unit_csv(unit):
    df = latest_df()
    unit_name = unquote(unit)

    if df is None or "Unit" not in df.columns:
        flash("No CSV data available for that unit.", "error")
        return redirect(url_for("reports.unit_overview", unit=unit))

    subset = df[df["Unit"].astype(str).str.strip() == unit_name].copy()
    buf = io.StringIO()
    subset.to_csv(buf, index=False)
    buf.seek(0)
    return send_file(
        io.BytesIO(buf.getvalue().encode("utf-8")),
        mimetype="text/csv",
        as_attachment=True,
        download_name=f"{unit_name}_latest.csv"
    )

@admin_bp.post("/documents/<int:doc_id>/delete")
@admin_required
def delete_document(doc_id):
    doc = Document.query.get_or_404(doc_id)
    db.session.delete(doc)
    db.session.commit()
    flash(f"Deleted document: {doc.original_name}", "success")
    return redirect(url_for("admin.upload"))

@admin_bp.post("/csvs/<int:csv_id>/delete")
@admin_required
def delete_csv(csv_id):
    c = CsvArtifact.query.get_or_404(csv_id)

    # Optional: if you store CSVs on disk instead of DB, try removing file.
    path = getattr(c, "path", None)
    if path and os.path.isfile(path):
        try:
            os.remove(path)
        except Exception:
            pass  # don't block deletion if filesystem cleanup fails

    db.session.delete(c)
    db.session.commit()
    flash(f"Deleted CSV: {c.filename or c.id}", "success")
    return redirect(url_for("admin.upload"))

@admin_bp.post("/csv/<int:csv_id>/move/up")
@admin_required
def csv_move_up(csv_id):
    c = CsvArtifact.query.get_or_404(csv_id)
    # Find the next higher neighbor
    neighbor = (CsvArtifact.query
                .filter(CsvArtifact.sort_order > c.sort_order)
                .order_by(CsvArtifact.sort_order.asc())
                .first())
    if not neighbor:
        flash("Already at the top.", "info")
        return redirect(url_for("admin.upload"))
    c.sort_order, neighbor.sort_order = neighbor.sort_order, c.sort_order
    db.session.commit()
    return redirect(url_for("admin.upload"))

@admin_bp.post("/csv/<int:csv_id>/move/down")
@admin_required
def csv_move_down(csv_id):
    c = CsvArtifact.query.get_or_404(csv_id)
    # Find the next lower neighbor
    neighbor = (CsvArtifact.query
                .filter(CsvArtifact.sort_order < c.sort_order)
                .order_by(CsvArtifact.sort_order.desc())
                .first())
    if not neighbor:
        flash("Already at the bottom.", "info")
        return redirect(url_for("admin.upload"))
    c.sort_order, neighbor.sort_order = neighbor.sort_order, c.sort_order
    db.session.commit()
    return redirect(url_for("admin.upload"))

@admin_bp.post("/csv/<int:csv_id>/make-top")
@admin_required
def csv_make_top(csv_id):
    c = CsvArtifact.query.get_or_404(csv_id)
    from sqlalchemy import func
    max_order = db.session.query(func.coalesce(func.max(CsvArtifact.sort_order), 0)).scalar()
    c.sort_order = max_order + 1
    db.session.commit()
    return redirect(url_for("admin.upload"))
