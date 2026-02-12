from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()
login_manager = LoginManager()
login_manager.login_view = "auth.login"

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(255), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), nullable=False, default="user")  # "admin" or "user"

    def set_password(self, password: str):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)

    def is_admin(self) -> bool:
        return self.role == "admin"

class Document(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    original_name = db.Column(db.String(512), nullable=False)
    size_bytes    = db.Column(db.Integer, nullable=False)
    content_type  = db.Column(db.String(128), nullable=False, default="text/html")
    data          = db.Column(db.LargeBinary, nullable=False)  # Stored HTML table snippet bytes
    uploaded_at   = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    uploaded_by   = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)

class CsvArtifact(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename     = db.Column(db.String(512), nullable=False, default="output.csv")
    data         = db.Column(db.LargeBinary, nullable=False)   # CSV bytes
    generated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    note         = db.Column(db.String(512), nullable=True)    # optional (e.g., source batch info)
    sort_order   = db.Column(db.Integer, nullable=False, default=0)
