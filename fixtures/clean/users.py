def find_user(cursor, email: str):
    cursor.execute("SELECT id, name FROM users WHERE email = %s", [email])
    return cursor.fetchone()
