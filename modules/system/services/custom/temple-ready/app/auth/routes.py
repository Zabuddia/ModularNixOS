from flask import render_template, redirect, url_for, flash, request
from flask_login import login_user, logout_user, current_user
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, BooleanField, SubmitField
from wtforms.validators import DataRequired, Length
from ..models import User
from . import auth_bp

# Note: No public register route. Users are created via CLI.

class LoginForm(FlaskForm):
    username = StringField("Username", validators=[DataRequired()])
    password = PasswordField("Password", validators=[DataRequired()])
    remember = BooleanField("Remember me")
    submit = SubmitField("Log in")

@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated:
        # send them to their role-appropriate dashboard
        return redirect(url_for("admin.dashboard" if current_user.is_admin() else "main.dashboard"))

    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user and user.check_password(form.password.data):
            login_user(user, remember=form.remember.data)
            next_url = request.args.get("next")
            return redirect(next_url or url_for("admin.dashboard" if user.is_admin() else "main.dashboard"))
        flash("Invalid username or password", "error")
    return render_template("login.html", form=form)

@auth_bp.route("/logout")
def logout():
    logout_user()
    return redirect(url_for("auth.login"))