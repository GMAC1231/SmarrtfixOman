from flask_mail import Mail
from flask_socketio import SocketIO
from sqlalchemy import create_engine

mail = Mail()
socketio = SocketIO(cors_allowed_origins="*")
engine = None


def init_engine(database_url: str):
    global engine
    engine = create_engine(database_url, pool_pre_ping=True)
    return engine
