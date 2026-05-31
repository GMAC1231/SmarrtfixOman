from flask import Blueprint, jsonify, request

from services.email_service import approve_employee_email, pending_employee_email, reject_employee_email

bp = Blueprint("employee", __name__)


@bp.post("/pending-employee")
def pending_employee():
    data = request.get_json(force=True)
    pending_employee_email(data.get("email"), data.get("name", "Employee"))
    return jsonify({"success": True, "message": "Pending email sent"})


@bp.post("/approve-employee")
def approve_employee():
    data = request.get_json(force=True)
    approve_employee_email(data.get("email"), data.get("name", "Employee"))
    return jsonify({"ok": True, "message": "Approve email sent"})


@bp.post("/reject-employee")
def reject_employee():
    data = request.get_json(force=True)
    reject_employee_email(data.get("email"), data.get("name", "Employee"))
    return jsonify({"ok": True, "message": "Reject email sent"})
