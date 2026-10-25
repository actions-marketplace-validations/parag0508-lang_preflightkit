<!-- Generated from docs/security/dotnet.md by scripts/sync-plugin.sh. Edit the original. -->

# .NET / ASP.NET Core Security Guide

## Top risks and the fix for each

### 1. SQL injection with EF Core
```csharp
// DANGEROUS: string concatenation
db.Users.FromSqlRaw("SELECT * FROM Users WHERE Email = '" + email + "'");

// SAFE: interpolated version is parameterized automatically
db.Users.FromSql($"SELECT * FROM Users WHERE Email = {email}");
```
Normal LINQ queries are parameterized.

### 2. Insecure deserialization
`BinaryFormatter` is unsafe and was removed in .NET 9. Use `System.Text.Json`.
With Newtonsoft.Json, never set `TypeNameHandling` to anything other than `None`
for untrusted input.

### 3. CSRF
For MVC and Razor Pages, keep anti-forgery validation on
(`[ValidateAntiForgeryToken]` or the global filter).

### 4. Pipeline essentials
```csharp
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/error");   // no developer exception page in prod
    app.UseHsts();
}
app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
```
Add a fallback authorization policy so new endpoints require login by default.

### 5. Secrets
Use User Secrets in development and environment variables or Key Vault in
production. Never put secrets in `appsettings.json` in source control.

## Quick self-check
```bash
dotnet --version                              # supported release?
dotnet list package --vulnerable --include-transitive
semgrep --config=p/csharp .
```
