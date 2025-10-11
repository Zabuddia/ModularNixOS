from ..models import CsvArtifact
import pandas as pd
from io import BytesIO

def latest_df():
    """Load the most recent CSV artifact into a DataFrame."""
    latest = CsvArtifact.query.order_by(CsvArtifact.generated_at.desc()).first()
    if not latest:
        return None
    # Only CSV expected here; if you kept any old XLSX around, add a branch for that.
    return pd.read_csv(BytesIO(latest.data))

def units_from_df(df: pd.DataFrame) -> list[str]:
    if df is None or "Unit" not in df.columns:
        return []
    return sorted([str(u) for u in df["Unit"].dropna().unique()])