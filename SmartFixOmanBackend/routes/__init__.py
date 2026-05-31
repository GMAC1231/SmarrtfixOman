from routes.admin_routes import bp as admin_bp
from routes.chat_routes import bp as chat_bp
from routes.employee_routes import bp as employee_bp
from routes.feedback_routes import bp as feedback_bp
from routes.health_routes import bp as health_bp
from routes.profile_routes import bp as profile_bp
from routes.routing_routes import bp as routing_bp


def register_routes(app):
    app.register_blueprint(health_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(chat_bp)
    app.register_blueprint(employee_bp)
    app.register_blueprint(feedback_bp)
    app.register_blueprint(profile_bp)
    app.register_blueprint(routing_bp)
