from urllib.parse import unquote
from flask import render_template
from flask_login import login_required
from . import reports_bp
from app.services.dashboard import latest_df
from app.services.reports import filter_active_with_next, filter_completed

@reports_bp.route("/stake")
@login_required
def stake_overview():
    df = latest_df()
    if df is None:
        return render_template(
            "report_stake.html",
            rows_next=[],
            rows_completed=[],
            rows=[]
        )

    rows_next = filter_active_with_next(df)
    rows_completed = filter_completed(df)

    return render_template(
        "report_stake.html",
        rows_next=rows_next,
        rows_completed=rows_completed,
    )

@reports_bp.route("/units/<path:unit>")
@login_required
def unit_overview(unit):
    unit_name = unquote(unit)
    df = latest_df()

    if df is None or "Unit" not in df.columns:
        return render_template(
            "report_unit.html",
            unit=unit_name,
            rows_next=[],
            rows_completed=[],
            rows=[]
        )

    subset = df[df["Unit"].astype(str).str.strip() == unit_name].copy()

    rows_next = filter_active_with_next(subset)
    rows_completed = filter_completed(subset)

    return render_template(
        "report_unit.html",
        unit=unit_name,
        rows_next=rows_next,
        rows_completed=rows_completed,
    )