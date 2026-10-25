<!-- Generated from docs/security/php.md by scripts/sync-plugin.sh. Edit the original. -->

# PHP Hardening Guide

PHP still powers a large share of the web, which makes it a constant target.
This guide covers two things: (1) keeping the PHP **runtime** patched — the
lesson of PHP2Shell — and (2) writing PHP **code** that doesn't open the common
holes.

---

## Part 1 — Keep the runtime patched (the PHP2Shell lesson)

In October 2026, two critical remote-code-execution flaws were found in PHP core
itself:

- **CVE-2026-109618** — a flaw in how PHP handles out-of-memory conditions during request processing.
- **CVE-2026-109619** — a use-after-free in PHP's request-state management.

Both are rated **CVSS 9.2** and allow **unauthenticated** remote code execution.
Because the bug lives in the runtime, it affects every common way of serving
PHP: **PHP-FPM, Apache mod_php, php-cgi, FrankenPHP, and LiteSpeed**. The risk
was rated highest for `mod_php`, where an unauthenticated request can trigger the
flaw before any application code runs.

### Fixed versions

| Branch | Upgrade to |
|--------|-----------|
| PHP 8.5.x | 8.5.12 |
| PHP 8.4.x | 8.4.27 |
| PHP 8.3.x | 8.3.36 |
| PHP 8.2.x | 8.2.35 |

PHP 8.1 and older are **end-of-life** and received no fix. If you're on them,
upgrading the branch is the only real remediation.

### What to actually do

1. **Find every PHP install**, including ones bundled inside third-party apps,
   appliances, and containers. Run `php -v` everywhere; check container images too.
2. **Upgrade to a fixed version**, then **restart the workers** — for PHP-FPM,
   restarting replaces the running PHP workers (an `apt upgrade` alone may not).
3. **Prioritize internet-facing systems.**
4. If you genuinely can't patch immediately, the PHP project described temporary
   mitigations (e.g. for the use-after-free path, disabling
   `session.upload_progress.enabled` and restarting workers; a memory-limit
   setting for the OOM path). These are stopgaps — **patching is the fix**.
5. **Hunt for compromise**: unexpected processes, new files/web shells, strange
   outbound connections, or new accounts tied to PHP/web-server services.

> Always confirm version numbers and mitigations against the official advisory at
> **php.net** before acting — advisories get updated.

---

## Part 2 — Write PHP that doesn't get owned

### SQL injection → always use prepared statements

```php
// DANGEROUS — never do this
$result = $db->query("SELECT * FROM users WHERE email = '$email'");

// SAFE — parameterized query with PDO
$stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch();
```

### Command injection → avoid passing input to shell

```php
// DANGEROUS
system("convert $userFile out.png");

// SAFER — validate strictly, use escapeshellarg, prefer native libraries
$safe = escapeshellarg($userFile);
system("convert $safe out.png");
```
Better still: use a library that doesn't shell out at all.

### Never eval user input / never deserialize untrusted data

```php
// DANGEROUS — remote code execution waiting to happen
eval($_GET['code']);
$obj = unserialize($_POST['data']);
```
Avoid `eval()` entirely. For untrusted structured data use `json_decode()`, not
`unserialize()`.

### Cross-site scripting (XSS) → escape on output

```php
// Escape for HTML context
echo htmlspecialchars($userInput, ENT_QUOTES, 'UTF-8');
```
Set a Content-Security-Policy header as a second layer.

### Protect secrets and config files

- Keep `.env` and config **outside the web root**, or block access at the server:
  ```apache
  # Apache
  <FilesMatch "^\.env">
      Require all denied
  </FilesMatch>
  ```
  ```nginx
  # Nginx
  location ~ /\.env { deny all; return 404; }
  ```
- Verify: fetching `https://yourapp/.env` must return 404, never the file.

### File uploads

- Validate type by content, not just extension.
- Store uploads **outside the web root** and serve them through a controller.
- Never let an upload directory execute PHP (`php_admin_flag engine off`, or
  nginx config that doesn't pass that path to PHP-FPM).

### Sessions & cookies

```php
session_set_cookie_params([
    'httponly' => true,
    'secure'   => true,
    'samesite' => 'Lax',
]);
```
Regenerate the session ID on login (`session_regenerate_id(true)`).

### php.ini production settings

```ini
display_errors = Off          ; don't leak stack traces to users
log_errors = On
expose_php = Off              ; hide the PHP version banner
allow_url_include = Off
session.cookie_httponly = On
session.cookie_secure = On
session.use_strict_mode = On
```

### Dependencies

- Run `composer audit` in CI and fix flagged packages.
- Keep `composer.lock` committed so builds are reproducible.

---

## Quick self-check for a PHP app

```bash
php -v                                  # supported & patched version?
curl -s -o /dev/null -w "%{http_code}" https://yourapp/.env   # must be 404
composer audit                          # dependency CVEs
grep -rn "eval(\|unserialize(\|system(\|exec(" ./src   # review each hit
```
