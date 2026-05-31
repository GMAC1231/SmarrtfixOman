from flask import Blueprint, current_app, jsonify, request
import requests
from firebase_admin import firestore as fb_fs

from services.firebase_service import get_firestore, verify_token
from utils.helpers import decode_polyline5, gen_trip_id, parse_latlng

bp = Blueprint("routing", __name__)


@bp.get("/route")
def route():
    p_from = parse_latlng((request.args.get("from") or "").strip())
    p_to = parse_latlng((request.args.get("to") or "").strip())
    if not p_from or not p_to:
        return jsonify({"error": "from/to must be 'lat,lng'"}), 400

    flonlat = f"{p_from[1]},{p_from[0]}"
    tlonlat = f"{p_to[1]},{p_to[0]}"
    url = f"{current_app.config['OSRM_BASE']}/route/v1/{current_app.config['OSRM_PROFILE']}/{flonlat};{tlonlat}?alternatives=false&overview=full&geometries=polyline"
    try:
        res = requests.get(url, timeout=current_app.config["OSRM_TIMEOUT_SEC"])
        data = res.json()
    except Exception as exc:
        return jsonify({"error": f"router unreachable: {exc}"}), 502

    if res.status_code != 200 or data.get("code") != "Ok" or not data.get("routes"):
        return jsonify({"error": "no route"}), 422

    r0 = data["routes"][0]
    poly = r0.get("geometry") or ""
    return jsonify({
        "polyline": poly,
        "points": decode_polyline5(poly) if poly else [],
        "distanceKm": round(float(r0.get("distance", 0.0)) / 1000.0, 3),
        "etaSec": max(int(r0.get("duration", 0)), 0),
        "source": "osrm",
    }), 200


@bp.post("/select")
def select_offer():
    fs = get_firestore()
    if fs is None:
        return jsonify({"error": "firestore not available"}), 500
    decoded = verify_token()
    if decoded is None and not current_app.config.get("DEV_ALLOW_NO_AUTH"):
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    req_id = (data.get("requestId") or "").strip()
    emp_id = (data.get("employeeId") or "").strip()
    if not req_id or not emp_id:
        return jsonify({"error": "requestId and employeeId are required"}), 400

    req_ref = fs.collection("serviceRequests").document(req_id)
    emp_pub_ref = fs.collection("publicUsers").document(emp_id)
    trip_id = gen_trip_id()

    @fb_fs.transactional
    def _tx(tx: fb_fs.Transaction):
        snap = req_ref.get(transaction=tx)
        if not snap.exists:
            raise ValueError("missing")
        request_data = snap.to_dict() or {}
        if str(request_data.get("status") or "pending") != "bidding":
            raise ValueError("taken")
        emp_snap = emp_pub_ref.get(transaction=tx)
        emp = emp_snap.to_dict() if emp_snap.exists else {}
        tx.update(req_ref, {
            "status": "accepted",
            "employeeId": emp_id,
            "employeeName": emp.get("name"),
            "employeePhone": emp.get("phone"),
            "employeeFare": emp.get("fare"),
            "employeeProfession": emp.get("profession"),
            "employeePhotoUrl": emp.get("photoUrl") or emp.get("profileImage"),
            "acceptedAt": fb_fs.SERVER_TIMESTAMP,
            "tripId": trip_id,
        })

    try:
        _tx(fs.transaction())
        return jsonify({"ok": True, "tripId": trip_id}), 200
    except ValueError as exc:
        if str(exc) == "taken":
            return jsonify({"ok": False, "error": "already accepted"}), 409
        if str(exc) == "missing":
            return jsonify({"ok": False, "error": "request not found"}), 404
        return jsonify({"ok": False, "error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"ok": False, "error": f"{type(exc).__name__}: {exc}"}), 500
