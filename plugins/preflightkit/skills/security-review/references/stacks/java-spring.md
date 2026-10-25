<!-- Generated from docs/security/java-spring.md by scripts/sync-plugin.sh. Edit the original. -->

# Java / Spring Boot Security Guide

## Top risks and the fix for each

### 1. Actuator endpoints exposed
Spring Boot Actuator can expose environment variables, heap dumps, and config.
Expose only what you need:
```properties
management.endpoints.web.exposure.include=health,info
management.endpoint.health.show-details=never
```
Put any other actuator endpoints behind authentication on an internal port.

### 2. SQL / JPQL injection
```java
// DANGEROUS
em.createQuery("FROM User WHERE email = '" + email + "'");

// SAFE
em.createQuery("FROM User WHERE email = :email", User.class)
  .setParameter("email", email);
```
Spring Data derived queries (`findByEmail`) and `@Query` with parameters are safe.

### 3. Unsafe deserialization
Never deserialize untrusted data with `ObjectInputStream`. For Jackson, don't
enable default typing (`activateDefaultTyping`) on input you don't control.

### 4. XML external entities (XXE)
Turn off DTDs and external entities in XML parsers:
```java
DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
```

### 5. Spring Security configuration
- Deny by default. End your rules with `.anyRequest().authenticated()`.
- Keep CSRF protection on for browser sessions. Turn it off only for truly
  stateless token APIs.
- Use `BCryptPasswordEncoder` or `Argon2PasswordEncoder`.

### 6. Dependency risk (the Log4Shell lesson)
Log4Shell (CVE-2021-44228) showed that one transitive dependency can expose
nearly every Java app. You need to know your full dependency tree:
```bash
mvn dependency:tree
mvn org.owasp:dependency-check-maven:check     # or: trivy fs .
```

## Quick self-check
```bash
java -version                       # on a supported LTS release?
trivy fs --severity CRITICAL,HIGH .
semgrep --config=p/java .
curl -s https://yourapp/actuator/env   # must NOT return data
```
