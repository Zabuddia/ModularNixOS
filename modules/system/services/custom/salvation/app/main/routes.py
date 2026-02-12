from flask import (
    render_template,
    abort,
    request,
    redirect,
    url_for,
    send_file,
    jsonify,
)
from flask_login import login_required, current_user
from sqlalchemy.orm import joinedload
from ..models import CsvArtifact
from io import BytesIO
from urllib.parse import unquote
import pandas as pd
import io

from . import main_bp

from app.services.dashboard import latest_df, units_from_df

def _save_new_csv_artifact(df: pd.DataFrame, note: str | None = None):
    csv_bytes = df.to_csv(index=False).encode("utf-8")
    art = CsvArtifact(
        data=csv_bytes,
        generated_at=datetime.utcnow(),
        note=note or "Updated Active flag"
    )
    db.session.add(art)
    db.session.commit()
    return art

@main_bp.route("/")
def root():
    # Send logged-in folks to the right dashboard; others to login
    if current_user.is_authenticated:
        if current_user.is_admin():
            return redirect(url_for("admin.dashboard"))
        return redirect(url_for("main.dashboard"))
    return redirect(url_for("auth.login"))

@main_bp.route("/dashboard")
@login_required
def dashboard():
    """
    Shows a list of Units from the most recent CSV, linking to each unit page.
    """
    df = latest_df()
    units = units_from_df(df)
    return render_template("dashboard.html", units=units)

@main_bp.route("/unit/<path:unit>")
@login_required
def unit_detail(unit: str):
    """
    Shows a table of Name, Age, Active for the given unit, from the latest CSV.
    """
    df = latest_df()
    if df is None or "Unit" not in df.columns:
        return render_template("unit.html", unit=unquote(unit), rows=[])

    unit_name = unquote(unit)
    subset = df[df["Unit"].astype(str).str.strip() == unit_name].copy()

    # Be tolerant if columns are missing
    for col in ["Name", "Age", "Active"]:
        if col not in subset.columns:
            subset[col] = "" if col != "Active" else False

    # Keep just the needed columns, in order
    subset = subset[["Name", "Age", "Active"]]

    # Convert to simple records for Jinja
    rows = subset.to_dict(orient="records")

    return render_template("unit.html", unit=unit_name, rows=rows)

@main_bp.route("/unit/<path:unit>/set_active", methods=["POST"])
@login_required
def set_active(unit):
    name = (request.form.get("name") or "").strip()
    # Don't let Werkzeug cast to int here; validate ourselves so we can error nicely
    age_str = request.form.get("age", "").strip()
    active = (request.form.get("active", "false").strip().lower() == "true")

    # Validate inputs early
    try:
        # Accept ints like "18" only; reject blanks/garbage
        age_val = int(age_str)
    except (TypeError, ValueError):
        return jsonify({"success": False, "error": "Invalid age"}), 400

    # Load latest artifact
    latest = CsvArtifact.query.order_by(CsvArtifact.generated_at.desc()).first()
    if not latest:
        return jsonify({"success": False, "error": "No CSV found"}), 400

    df = pd.read_csv(io.BytesIO(latest.data))

    # Ensure required columns exist
    for col in ("Unit", "Name", "Age"):
        if col not in df.columns:
            return jsonify({"success": False, "error": f"Missing '{col}' column in CSV"}), 400

    # Build robust match mask:
    # - Compare Unit/Name as trimmed strings
    # - Compare Age using numeric coercion to avoid IntCastingNaNError
    unit_ser = df["Unit"].astype(str).str.strip()
    name_ser = df["Name"].astype(str).str.strip()
    age_ser  = pd.to_numeric(df["Age"], errors="coerce")  # float with NaN if bad

    mask = (unit_ser == unit) & (name_ser == name) & (age_ser == age_val)

    if not mask.any():
        # Optional: help debug mismatches by showing close candidates
        return jsonify({"success": False, "error": "Person not found"}), 404

    # Ensure Active column exists and is boolean-like
    if "Active" not in df.columns:
        df["Active"] = False

    # Set the value (pandas will store True/False fine in CSV)
    df.loc[mask, "Active"] = bool(active)

    # Save updated CSV back to the artifact
    buf = io.BytesIO()
    df.to_csv(buf, index=False)
    latest.data = buf.getvalue()

    from app import db
    db.session.commit()

    return jsonify({"success": True})