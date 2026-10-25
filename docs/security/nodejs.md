# Node.js / Express Security Guide

Covers Node.js backends (Express, Fastify, Koa, NestJS). Most items apply to any
Node server.

## Top risks and the fix for each

### 1. SQL / NoSQL injection
```js
// DANGEROUS
await db.query(`SELECT * FROM users WHERE email = '${email}'`);

// SAFE (pg)
await db.query('SELECT * FROM users WHERE email = $1', [email]);
```
For MongoDB, reject objects where you expect strings, so `{ "$ne": null }`
can't be used to slip past a login check:
```js
if (typeof req.body.email !== 'string') return res.status(400).end();
```
Validate every request body with a schema library (zod, joi, ajv).

### 2. Command injection
```js
// DANGEROUS: runs through a shell
exec(`convert ${file} out.png`);

// SAFER: no shell, arguments passed as an array
execFile('convert', [file, 'out.png']);
```
Never pass user input to `eval`, `new Function`, or `vm` as code.

### 3. Prototype pollution
Merging untrusted JSON into objects (`_.merge`, hand-written deep-merge code) can
set `__proto__` and change how the whole app behaves. Validate input shape first,
use `Object.create(null)` for lookup maps, and keep lodash and similar libraries
up to date.

### 4. Path traversal
```js
const base = path.resolve('uploads');
const target = path.resolve(base, req.params.name);
if (!target.startsWith(base + path.sep)) return res.status(400).end();
```

### 5. Authentication and JWT
- Always verify tokens with a fixed algorithm list: `jwt.verify(token, key, { algorithms: ['HS256'] })`.
- Hash passwords with `bcrypt` or `argon2`, never with `crypto.createHash('md5')`.
- Cookies: `httpOnly: true, secure: true, sameSite: 'lax'`.

### 6. Security headers and abuse limits
```js
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

app.disable('x-powered-by');
app.use(helmet());                                   // CSP, HSTS, nosniff, etc.
app.use('/login', rateLimit({ windowMs: 15 * 60_000, limit: 20 }));
app.use(express.json({ limit: '100kb' }));           // cap body size
```

### 7. Errors and configuration
- `NODE_ENV=production`, and don't send stack traces to clients.
- Secrets come from the environment or a secrets manager. Never commit `.env`.

## Supply chain (where Node apps get hit hardest)
- Commit `package-lock.json` and install with `npm ci` in CI.
- Run `npm audit --audit-level=high` on every PR.
- Before adding a package, check that it's real, maintained, and not a typosquat.
  Be extra careful with packages an AI assistant suggested.
- Consider `npm config set ignore-scripts true` for installs you don't trust.

## Quick self-check
```bash
node -v                     # on an active LTS release?
npm audit --audit-level=high
npx semgrep --config=p/nodejs .
grep -rnE "eval\(|new Function|child_process.*exec\(" src/
```
