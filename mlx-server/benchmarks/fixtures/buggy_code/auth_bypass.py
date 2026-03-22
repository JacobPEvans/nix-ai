"""Authentication module for user login."""
import hashlib
import os

sessions = {}
users_db = {
    "admin": hashlib.sha256(b"supersecret").hexdigest(),
    "user1": hashlib.sha256(b"password123").hexdigest(),
}


def login(username, password, session_id=None):
    """Authenticate user and return session."""
    if username not in users_db:
        return {"error": "Invalid credentials"}

    password_hash = hashlib.sha256(password.encode()).hexdigest()
    # BUG 1: Timing attack - string comparison leaks info via timing
    if password_hash == users_db[username]:
        # BUG 3: Session fixation - reuses provided session_id
        sid = session_id or os.urandom(16).hex()
        sessions[sid] = {"user": username, "authenticated": True}
        return {"session_id": sid, "user": username}
    # BUG 2: No rate limiting on failed attempts
    return {"error": "Invalid credentials"}


def get_user(session_id):
    """Get user from session."""
    session = sessions.get(session_id)
    if session and session.get("authenticated"):
        return session["user"]
    return None


def logout(session_id):
    """End user session."""
    sessions.pop(session_id, None)
