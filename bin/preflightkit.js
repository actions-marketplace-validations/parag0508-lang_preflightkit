#!/usr/bin/env node
// PreflightKit CLI: is your app ready to ship?
// Usage: npx preflightkit [check] [path] | init [--force] | checklist | --help | --version

'use strict';

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const pkg = require(path.join(ROOT, 'package.json'));
const REPO = 'https://github.com/parag0508-lang/preflightkit';

const HELP = `PreflightKit ${pkg.version}: is your app ready to ship?

Usage:
  npx preflightkit [path]           Run the security self-check (default: current folder)
  npx preflightkit check [path]     Same as above
  npx preflightkit init [--force]   Add the GitHub Actions workflow to this project
  npx preflightkit checklist        Print the pre/post-deploy security checklist
  npx preflightkit --help | --version

The check runs free scanners you have installed (gitleaks, Semgrep, Trivy,
npm/composer/pip/bundle/go/dotnet audits) and flags risky code patterns.
It only reads your code. Use it on projects you own or are authorized to test.

Guides for every stack: ${REPO}`;

function hasBash() {
  const r = spawnSync('bash', ['--version'], { stdio: 'ignore' });
  return r.status === 0;
}

function check(target) {
  const dir = path.resolve(target || '.');
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
    console.error(`preflightkit: "${target}" is not a folder.`);
    return 2;
  }
  if (!hasBash()) {
    console.error('preflightkit: the check needs bash. On Windows, run it from Git Bash or WSL.');
    return 2;
  }
  const script = path.join(ROOT, 'scripts', 'security-check.sh');
  const r = spawnSync('bash', [script, dir], { stdio: 'inherit' });
  return r.status === null ? 1 : r.status;
}

function init(force) {
  const dest = path.join(process.cwd(), '.github', 'workflows', 'preflightkit.yml');
  if (fs.existsSync(dest) && !force) {
    console.error(`preflightkit: ${path.relative(process.cwd(), dest)} already exists. Use --force to overwrite.`);
    return 1;
  }
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(path.join(ROOT, 'templates', 'preflightkit.yml'), dest);
  console.log(`Created ${path.relative(process.cwd(), dest)}`);
  console.log('Commit and push it: every push and pull request will now be checked.');
  return 0;
}

function checklist() {
  process.stdout.write(fs.readFileSync(path.join(ROOT, 'SECURITY-CHECKLIST.md'), 'utf8'));
  return 0;
}

function main(argv) {
  const [cmd, ...rest] = argv;
  switch (cmd) {
    case '-h': case '--help': case 'help':
      console.log(HELP); return 0;
    case '-v': case '--version':
      console.log(pkg.version); return 0;
    case 'init':
      return init(rest.includes('--force'));
    case 'checklist':
      return checklist();
    case 'check':
      return check(rest[0]);
    case undefined:
      return check('.');
    default:
      if (cmd.startsWith('-')) { console.error(`preflightkit: unknown option ${cmd}\n\n${HELP}`); return 2; }
      return check(cmd);   // treat as a path
  }
}

process.exitCode = main(process.argv.slice(2));
