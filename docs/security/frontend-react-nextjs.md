# Frontend Security: React, Next.js, Vue, and SPAs

Frontend code runs on the user's machine. **Anything shipped to the browser is
public.** Real security checks always happen on the server.

## Top risks and the fix for each

### 1. Secrets in the bundle
- Any variable prefixed `NEXT_PUBLIC_`, `VITE_`, or `REACT_APP_` ends up in
  the JavaScript bundle that every visitor downloads.
- Never put API secrets, database URLs, or private keys in those variables.
  Call a backend route that holds the secret instead.

### 2. XSS
- `dangerouslySetInnerHTML` (React) and `v-html` (Vue) bypass escaping. If you
  must render HTML, sanitize it with DOMPurify first.
- Validate URLs before putting them in `href`, so a `javascript:` URL can't run
  code.
- Set a Content-Security-Policy.

### 3. Hiding a button doesn't protect anything
Hiding an admin button in the UI doesn't stop anyone. Every API route, server
action, and route handler must check authentication and authorization on the
server.

### 4. Next.js specifics
- **Server Actions are public endpoints.** Authenticate and authorize inside
  each action, and validate its inputs.
- **Don't rely on middleware alone for auth.** CVE-2025-29927 let attackers skip
  Next.js middleware entirely with a crafted header. Check auth again close to
  the data.
- **Keep React and Next.js patched.** In December 2025, a critical remote code
  execution flaw in React Server Components ("React2Shell", CVE-2025-55182)
  affected Next.js App Router apps. Framework updates are security updates.
  Confirm affected versions in the official advisories.

### 5. Tokens in the browser
Session tokens are safest in `HttpOnly; Secure; SameSite` cookies. Tokens kept in
`localStorage` can be stolen by any XSS.

## Quick self-check
```bash
npm audit --audit-level=high
npx next info                      # Next.js version: is it the latest patch?
grep -rn "dangerouslySetInnerHTML\|v-html" src/
grep -rnE "NEXT_PUBLIC_.*(SECRET|KEY|TOKEN|PASSWORD)" .
```
