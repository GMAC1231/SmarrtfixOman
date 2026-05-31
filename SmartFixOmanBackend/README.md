# SmartFixOman Backend - Rearranged Version

This is a cleaned and modular version of your original single-file Flask backend.

## Run locally

```bash
pip install -r requirements.txt
python app.py
```

## Main files

- `app.py` - starts Flask, Socket.IO, CORS, Firebase, database, routes.
- `config.py` - all environment variables.
- `extensions.py` - Mail, Socket.IO, SQLAlchemy engine.
- `routes/` - all API endpoints separated by feature.
- `services/` - email, Firebase, Socket.IO helpers.
- `database/` - database connection and table creation.
- `utils/` - helper functions.

## Important endpoints kept

- `/health`
- `/healthz`
- `/update-profile`
- `/profile-image/<email>`
- `/api/chat/upload-image`
- `/api/chat/send`
- `/sound_event`
- `/pending-employee`
- `/approve-employee`
- `/reject-employee`
- `/api/feedback`
- `/api/admin/users`
- `/api/admin/feedback`
- `/route`
- `/select`
- `/api/provider/<firebase_uid>`

## Notes

I also fixed one backend issue from the old file: in `/api/chat/send`, the local variable `text` was conflicting with SQLAlchemy `text()`. It is now renamed to `message_text`, and SQLAlchemy text is imported as `sql_text`.
