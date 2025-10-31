import click
from flask import Flask
from .config import Config
from .models import db, login_manager, User
from zoneinfo import ZoneInfo

def create_app():
	app = Flask(__name__)
	app.config.from_object(Config)

	# Refuse to run in production with a placeholder secret
	if (not app.debug) and (app.config["SECRET_KEY"] in [None, "", "dev-only-change-me", "CHANGE_ME"]):
		raise RuntimeError("SECRET_KEY is not set. Put it in environment or .env (not in git).")

	db.init_app(app)
	login_manager.init_app(app)

	# ---- Add New York time Jinja filter ----
	@app.template_filter("fmt_ny")
	def fmt_ny(dt, fmt="%Y-%m-%d %H:%M"):
		if not dt:
			return ""
		if dt.tzinfo is None:
			dt = dt.replace(tzinfo=ZoneInfo("UTC"))
		return dt.astimezone(ZoneInfo("America/New_York")).strftime(fmt)

	with app.app_context():
		db.create_all()

	from .auth import auth_bp
	from .main import main_bp
	from .admin import admin_bp
	from .reports import reports_bp
	app.register_blueprint(auth_bp)
	app.register_blueprint(main_bp)
	app.register_blueprint(admin_bp)
	app.register_blueprint(reports_bp)

	@login_manager.user_loader
	def load_user(user_id):
		return User.query.get(int(user_id))

	# ---- CLI: create users (no public registration) ----
	@app.cli.command("create-user")
	@click.option("--username", prompt=True)
	@click.option("--password", prompt=True, hide_input=True, confirmation_prompt=True)
	@click.option("--role", type=click.Choice(["user", "admin"]), default="user")
	def create_user(username, password, role):
		"""Create a user from the command line."""
		if User.query.filter_by(username=username).first():
			click.echo("User already exists.")
			return
		user = User(username=username, role=role)
		user.set_password(password)
		db.session.add(user)
		db.session.commit()
		click.echo(f"Created {role} user: {username}")

	@app.cli.command("delete-user")
	@click.option("--username", prompt=True)
	@click.confirmation_option(prompt="Are you sure you want to delete this user?")
	def delete_user(username):
		"""Delete a user by username."""
		user = User.query.filter_by(username=username).first()
		if not user:
			click.echo("No user found with that username.")
			return
		db.session.delete(user)
		db.session.commit()
		click.echo(f"Deleted user: {username}")

	@app.cli.command("list-users")
	def list_users():
		"""List all users with their roles."""
		users = User.query.order_by(User.username.asc()).all()
		if not users:
			click.echo("No users found.")
			return
		for u in users:
			click.echo(f"{u.id}: {u.username}  [{u.role}]")

	@app.cli.command("set-role")
	@click.option("--username", prompt=True)
	@click.option("--role", type=click.Choice(["user", "admin"]), prompt=True)
	def set_role(username, role):
		"""Change a user's role."""
		user = User.query.filter_by(username=username).first()
		if not user:
			click.echo("No user found with that username.")
			return
		user.role = role
		db.session.commit()
		click.echo(f"Updated role for {username} → {role}")

	@app.cli.command("set-password")
	@click.option("--username", prompt=True)
	@click.option("--password", prompt=True, hide_input=True, confirmation_prompt=True)
	def set_password(username, password):
		"""Reset a user's password."""
		user = User.query.filter_by(username=username).first()
		if not user:
			click.echo("No user found with that username.")
			return
		user.set_password(password)
		db.session.commit()
		click.echo(f"Password updated for {username}")

	return app