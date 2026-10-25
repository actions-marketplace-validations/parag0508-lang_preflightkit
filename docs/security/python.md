# Python Security Guide (Django, Flask, FastAPI)

## Top risks and the fix for each

### 1. SQL injection
```python
# DANGEROUS
cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")

# SAFE: driver parameters
cursor.execute("SELECT * FROM users WHERE email = %s", [email])

# Django ORM is safe by default. If you need raw SQL, pass params:
User.objects.raw("SELECT * FROM app_user WHERE email = %s", [email])
```

### 2. Code execution through "convenience" functions
| Dangerous | Use instead |
|-----------|-------------|
| `pickle.loads(untrusted)` | `json.loads` |
| `yaml.load(data)` | `yaml.safe_load(data)` |
| `eval()` / `exec()` on input | a parser or an explicit allowlist |
| `subprocess.run(cmd, shell=True)` | `subprocess.run(["convert", f, "out.png"])` |

### 3. Template injection and XSS
- Django and Jinja2 autoescape by default. Don't turn it off, and be careful with
  `|safe`, `mark_safe`, and `Markup`.
- Never build templates from user input: `render_template_string(user_input)`
  leads to remote code execution.

### 4. Debug mode in production
- **Flask:** never run with `debug=True` or the Werkzeug debugger in production.
  It gives an interactive console to anyone who can trigger an error.
- **Django:** `DEBUG = False`, with `ALLOWED_HOSTS` set explicitly.

### 5. Path traversal and SSRF
- Resolve paths and confirm they stay inside the intended directory.
- If your server fetches URLs that users supply, check them against an allowlist
  and block internal and metadata addresses.

## Django production settings
```python
DEBUG = False
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
ALLOWED_HOSTS = ["example.com"]
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True
```
Then run Django's own checker: `python manage.py check --deploy`.

## FastAPI notes
- Declare Pydantic models for every request body. Validation is the first line of defense.
- Protect routes with dependencies such as `Depends(get_current_user)`, and check
  that the user owns the object they ask for, not only that they're logged in.
- Configure CORS with explicit origins. Don't combine `allow_origins=["*"]` with credentials.

## Quick self-check
```bash
python --version            # still a supported release?
pip-audit                   # known-vulnerable dependencies
bandit -r .                 # Python-specific static analysis
python manage.py check --deploy   # Django only
```
