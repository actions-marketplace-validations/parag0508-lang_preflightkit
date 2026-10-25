# Database Readiness Checklist

Data is the part of an app you can't redeploy. This checklist covers what keeps
it **safe, recoverable, correct and fast**, for PostgreSQL, MySQL/MariaDB,
MongoDB, and managed services (RDS, Cloud SQL, Supabase, PlanetScale, Atlas, Neon).

---

## 1. Not reachable by strangers
- [ ] **The database isn't exposed to the public internet.** It sits in a
      private network, or behind an IP allowlist. Exposed MongoDB, Redis and
      Elasticsearch instances are among the most common causes of data leaks.
- [ ] Every connection uses TLS, including inside the cloud.
- [ ] **Default and admin accounts have strong, unique passwords**, or use
      IAM-based authentication. Nothing is left on default credentials.
- [ ] Database credentials live in a secrets manager or environment variables,
      never in the repo.

## 2. Least privilege
- [ ] **The app connects as a limited user** that can read and write its own
      tables, but can't `DROP`, `ALTER`, or create users.
- [ ] Migrations run as a separate, more privileged user, only during deploys.
- [ ] Analytics and reporting use a read-only user, ideally on a read replica.
- [ ] **Multi-tenant data is isolated in the database**, for example with
      PostgreSQL Row-Level Security or a tenant ID enforced in every query, not
      only in application code.

## 3. Backups you've actually restored
- [ ] Automated backups are on, with **point-in-time recovery** where available.
- [ ] Backups are stored in a separate account or region, so one incident can't
      delete both the data and its backups.
- [ ] **A restore has been tested**, and you know how long it takes. A backup
      you've never restored is only a hope.
- [ ] Backups are encrypted, and access to them is restricted like production.

## 4. Correctness lives in the schema
- [ ] **Constraints in the database**, not only in app code: `NOT NULL`,
      `UNIQUE`, `FOREIGN KEY`, `CHECK`. Application bugs come and go; constraints
      catch them.
- [ ] Money is stored as integers (cents) or `NUMERIC`, never as float.
- [ ] Timestamps are stored in UTC (`timestamptz` in PostgreSQL).
- [ ] Operations that must succeed or fail together run in a transaction.

## 5. Safe migrations (zero downtime)
- [ ] **Migrations are in version control** and run automatically in CI/CD, never
      typed by hand into production.
- [ ] **Changes are made in backward-compatible steps:** add a nullable column →
      deploy code that writes it → backfill in batches → add the constraint →
      remove the old column in a later release.
- [ ] **Big tables get indexes without locking**: `CREATE INDEX CONCURRENTLY`
      in PostgreSQL, or online DDL in MySQL.
- [ ] Set a `lock_timeout` for migrations, so one blocked statement can't freeze
      the app.
- [ ] Every migration has been run against a copy of production-sized data first.

## 6. Performance
- [ ] **Columns used in filters, joins and sorting are indexed**, including
      foreign keys (PostgreSQL doesn't index them automatically).
- [ ] **No N+1 queries.** Load related data with joins or eager loading, not one
      query per row. Watch your query log or ORM debug output.
- [ ] Large lists are paginated. Prefer keyset (cursor) pagination over a large
      `OFFSET`.
- [ ] **Connection pooling** is configured (PgBouncer, RDS Proxy, or your
      platform's pooler). Serverless apps especially can run out of connections.
- [ ] Slow queries are tracked (`pg_stat_statements`, slow query log) and reviewed
      with `EXPLAIN ANALYZE`.

## 7. Personal data
- [ ] **Collect only what you need**, and know where each type of personal data lives.
- [ ] Highly sensitive fields (ID numbers, health data, tokens) are encrypted at
      the application level, on top of disk encryption.
- [ ] **You can delete or export one user's data** when asked. Laws like GDPR
      and India's DPDP Act require this.
- [ ] Old data is deleted on a schedule according to a retention policy.

---

## Quick checks (PostgreSQL examples)
```sql
-- Who can do what?
SELECT grantee, privilege_type, table_name
FROM information_schema.role_table_grants WHERE table_schema = 'public';

-- Foreign keys without an index
SELECT c.conrelid::regclass AS table_name, a.attname AS column_name
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid AND a.attnum = ANY (i.indkey));

-- Slowest queries (requires the pg_stat_statements extension)
SELECT query, calls, mean_exec_time FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 10;
```
```bash
# Is the database reachable from outside? Run this from a machine OUTSIDE your
# network, against your own host only. It should time out or be refused.
nc -zv your-db-host 5432
```
