from __future__ import annotations

from flask import request

from extensions import socketio

connected_users: dict[str, str] = {}


def register_socket_events() -> None:
    @socketio.on("connect")
    def handle_connect():
        print("SOCKET CLIENT CONNECTED")

    @socketio.on("register")
    def register_user(data):
        uid = (data or {}).get("uid")
        if uid:
            connected_users[uid] = request.sid
            print("REGISTERED =>", uid)


def emit_sound(receiver_id: str, payload: dict) -> bool:
    receiver_sid = connected_users.get(receiver_id)
    if not receiver_sid:
        print("USER NOT CONNECTED =>", receiver_id)
        return False
    socketio.emit("play_sound", payload, room=receiver_sid)
    print("SOUND EMITTED TO =>", receiver_id)
    return True
