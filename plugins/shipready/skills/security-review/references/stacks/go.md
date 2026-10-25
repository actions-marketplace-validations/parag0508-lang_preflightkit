<!-- Generated from docs/security/go.md by scripts/sync-plugin.sh. Edit the original. -->

# Go Security Guide

## Top risks and the fix for each

### 1. SQL injection
```go
// DANGEROUS
db.Query("SELECT * FROM users WHERE email = '" + email + "'")

// SAFE
db.Query("SELECT * FROM users WHERE email = $1", email)
```

### 2. XSS: use the right template package
`html/template` escapes output based on context. `text/template` doesn't escape
at all. Use `html/template` for anything that renders HTML.

### 3. Command injection
`exec.Command("convert", file, "out.png")` passes arguments without a shell,
which is safe. Never do `exec.Command("sh", "-c", userInput)`.

### 4. Path traversal
Use `os.Root` (Go 1.24 and later) to confine file access to a directory, or use
`filepath.Clean` and then confirm the result stays inside the base directory.

### 5. Server timeouts
A bare `http.ListenAndServe` has no timeouts, so slow clients can tie up
connections indefinitely (Slowloris). Set timeouts explicitly:
```go
srv := &http.Server{
    Addr:              ":8080",
    Handler:           mux,
    ReadHeaderTimeout: 5 * time.Second,
    ReadTimeout:       15 * time.Second,
    WriteTimeout:      15 * time.Second,
    IdleTimeout:       60 * time.Second,
}
```
Cap request bodies with `http.MaxBytesReader`.

### 6. Crypto
Use `crypto/rand` for tokens, never `math/rand`. Hash passwords with
`golang.org/x/crypto/bcrypt` or argon2.

## Quick self-check
```bash
go version                  # supported release?
govulncheck ./...           # reports only the vulnerabilities your code actually reaches
gosec ./...                 # Go static analysis
```
