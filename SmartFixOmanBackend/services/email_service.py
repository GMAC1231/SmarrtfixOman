from __future__ import annotations

import smtplib
import socket
import ssl
from typing import Optional, Tuple

from flask import current_app
from flask_mail import Message

from extensions import mail


def smtp_preflight() -> Tuple[bool, Optional[str]]:
    app = current_app
    if not app.config.get("SMTP_PREFLIGHT"):
        return True, None
    host = app.config["MAIL_SERVER"]
    port = int(app.config["MAIL_PORT"])
    user = app.config["MAIL_USERNAME"]
    pwd = app.config["MAIL_PASSWORD"]
    use_tls = bool(app.config["MAIL_USE_TLS"])
    use_ssl = bool(app.config["MAIL_USE_SSL"])
    timeout = app.config["MAIL_TIMEOUT_SEC"]

    if use_tls and use_ssl:
        return False, "MAIL_USE_TLS and MAIL_USE_SSL cannot both be true."
    if port == 587 and not use_tls:
        return False, "Port 587 requires MAIL_USE_TLS=true and MAIL_USE_SSL=false."
    if port == 465 and not use_ssl:
        return False, "Port 465 requires MAIL_USE_SSL=true and MAIL_USE_TLS=false."
    if not user or not pwd:
        return False, "MAIL_USERNAME and MAIL_PASSWORD are required for preflight."

    try:
        if use_ssl and port == 465:
            with smtplib.SMTP_SSL(host, port, timeout=timeout, context=ssl.create_default_context()) as s:
                s.ehlo(); s.login(user, pwd); s.noop()
        else:
            with smtplib.SMTP(host, port, timeout=timeout) as s:
                s.ehlo(); s.starttls(context=ssl.create_default_context()); s.ehlo(); s.login(user, pwd); s.noop()
        return True, None
    except (smtplib.SMTPServerDisconnected, ConnectionResetError, socket.timeout) as exc:
        return False, f"Connection closed/timeout: {exc}"
    except smtplib.SMTPAuthenticationError as exc:
        return False, f"Auth failed: {exc}"
    except ssl.SSLError as exc:
        return False, f"TLS handshake failed: {exc}"
    except Exception as exc:
        return False, f"Unexpected: {type(exc).__name__}: {exc}"


def send_status_email(to_email: str, subject: str, body: str) -> None:
    if current_app.config.get("DISABLE_MAIL"):
        print("MAIL DISABLED")
        return
    if not to_email:
        raise ValueError("Recipient email missing")
    msg = Message(
        subject=subject,
        recipients=[to_email],
        body=body,
        sender=current_app.config["MAIL_DEFAULT_SENDER"],
    )
    msg.charset = "utf-8"
    mail.send(msg)


def pending_employee_email(email: str, name: str = "Employee") -> None:
    send_status_email(email, "SmartFixOman Verification Pending ⏳", f"""
Hello {name},

Your SmartFixOman employee verification request has been submitted successfully.

Our admin team will review your information shortly.

You will receive another email once approved or rejected.

Thank you for joining SmartFixOman 🚀
""")


def approve_employee_email(email: str, name: str = "Employee") -> None:
    send_status_email(email, "SmartFixOman Employee Approved ✅", f"""
Hello {name},

Congratulations!

Your SmartFixOman employee account has been approved successfully.

You can now:
• Login
• Accept jobs
• Receive customer requests
• Start earning

Welcome to SmartFixOman 🚀

Best regards,
SmartFixOman Team
""")


def reject_employee_email(email: str, name: str = "Employee") -> None:
    send_status_email(email, "SmartFixOman Employee Request Rejected ❌", f"""
Hello {name},

Unfortunately, your SmartFixOman employee registration request has been rejected.

Please contact support for more details.

Best regards,
SmartFixOman Team
""")
