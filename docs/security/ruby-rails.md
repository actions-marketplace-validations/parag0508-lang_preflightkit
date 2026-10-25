# Ruby on Rails Security Guide

Rails is secure by default in many ways. Most real problems come from bypassing
those defaults.

## Top risks and the fix for each

### 1. SQL injection
```ruby
# DANGEROUS
User.where("email = '#{params[:email]}'")

# SAFE
User.where(email: params[:email])
User.where("email = ?", params[:email])
```
Be careful with `order`, `pluck`, and `select` built from params. Use an allowlist.

### 2. Mass assignment
Always use strong parameters:
```ruby
params.require(:user).permit(:name, :email)   # never permit :admin
```

### 3. XSS
ERB escapes output by default. Treat every `raw`, `html_safe`, and `<%==` as a
code-review red flag.

### 4. Dynamic dispatch and deserialization
- Never pass user input to `send`, `constantize`, or `public_send`.
- Use `YAML.safe_load`, and never `Marshal.load` untrusted data.

### 5. Production configuration
```ruby
config.force_ssl = true
config.consider_all_requests_local = false
```
Store secrets in `rails credentials:edit` (encrypted), and never commit `master.key`.

## Quick self-check
```bash
ruby -v && rails -v         # supported releases?
bundle exec brakeman        # Rails-specific static analysis
bundle exec bundle-audit check --update
```
