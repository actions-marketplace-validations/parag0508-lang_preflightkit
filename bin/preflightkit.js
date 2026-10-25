#!/usr/bin/env node
// PreflightKit CLI: is your app ready to ship?
// Usage: npx preflightkit [check] [path] [options] | doctor [path] | init [--force]
//        | rules [targets] [--force] | checklist | --help | --version

'use strict';

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const pkg = require(path.join(ROOT, 'package.json'));
const REPO = 'https://github.com/parag0508-lang/preflightkit';

const HELP = `PreflightKit ${pkg.version}: is your app ready to ship?

Usage:
  npx preflightkit [path] [options] Run the security self-check (default: current folder)
  npx preflightkit check [path]     Same as above
  npx preflightkit doctor [path]    Show which scanners are installed and how to add the rest
  npx preflightkit init [--force]   Add the GitHub Actions workflow to this project
  npx preflightkit rules [targets]  Give your AI coding assistant PreflightKit's secure-coding
                                    rules: --agents (AGENTS.md), --copilot, --cursor,
                                    --claude (CLAUDE.md), --windsurf, or --all.
                                    Default: --agents --copilot --cursor
  npx preflightkit checklist        Print the pre/post-deploy security checklist
  npx preflightkit --help | --version

Check options:
  --audit-level=LEVEL   Lowest dependency severity that blocks: low, moderate,
                        high (default) or critical
  --include-dev         Also audit development dependencies
  --strict              Treat advisory findings (risky patterns, Semgrep) as blocking

Exit code: 0 nothing blocking, 1 blocking findings, 2 a scanner could not run.
Accept a reviewed pattern match with a "preflightkit-ignore" comment on or above
the line, or list paths to skip in .preflightkitignore.

The check runs free scanners you have installed (gitleaks, Semgrep, Trivy,
npm/composer/pip/bundle/go/dotnet audits) and flags risky code patterns.
It only reads your code. Use it on projects you own or are authorized to test.

Guides for every stack: ${REPO}`;

const CHECK_OPTION = /^--(strict|include-dev|audit-level=(low|moderate|high|critical))$/;

// Finds an executable on PATH, like `which`.
function which(cmd) {
  const exts = process.platform === 'win32'
    ? ['', ...(process.env.PATHEXT || '.EXE;.CMD;.BAT').split(';')]
    : [''];
  for (const dir of (process.env.PATH || '').split(path.delimiter)) {
    if (!dir) continue;
    for (const ext of exts) {
      const p = path.join(dir, cmd + ext);
      try { if (fs.statSync(p).isFile()) return p; } catch { /* not here */ }
    }
  }
  return null;
}

// Returns the bash to run the check with, or null. On Windows, Git Bash is
// found even when it isn't on PATH, and System32\bash.exe is avoided: it is
// the WSL launcher, which can't read Windows paths.
function findBash() {
  if (process.env.PREFLIGHTKIT_BASH) return process.env.PREFLIGHTKIT_BASH;
  if (process.platform !== 'win32') {
    return spawnSync('bash', ['--version'], { stdio: 'ignore' }).status === 0 ? 'bash' : null;
  }
  const where = (cmd) => {
    const r = spawnSync('where', [cmd], { encoding: 'utf8' });
    return r.status === 0 ? r.stdout.split(/\r?\n/).filter(Boolean) : [];
  };
  const candidates = [];
  for (const base of [process.env.ProgramFiles, process.env['ProgramFiles(x86)'],
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'Programs')]) {
    if (base) candidates.push(path.join(base, 'Git', 'bin', 'bash.exe'));
  }
  for (const git of where('git')) {   // e.g. <Git>\cmd\git.exe or <Git>\mingw64\bin\git.exe
    candidates.push(path.join(path.dirname(git), '..', 'bin', 'bash.exe'));
    candidates.push(path.join(path.dirname(git), '..', '..', 'bin', 'bash.exe'));
  }
  const windir = process.env.SystemRoot || path.join(path.parse(process.cwd()).root, 'Windows');
  const system32 = path.join(windir, 'System32').toLowerCase();
  candidates.push(...where('bash').filter((p) => !p.toLowerCase().startsWith(system32)));
  return candidates.find((p) => fs.existsSync(p)) || null;
}

// Resolves a folder argument, or prints an error and returns null.
function folder(target) {
  const dir = path.resolve(target || '.');
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
    console.error(`preflightkit: "${target}" is not a folder.`);
    return null;
  }
  return dir;
}

function check(args) {
  const options = args.filter((a) => a.startsWith('-'));
  const paths = args.filter((a) => !a.startsWith('-'));
  const bad = options.find((o) => !CHECK_OPTION.test(o));
  if (bad) {
    console.error(`preflightkit: unknown option ${bad}\n\n${HELP}`);
    return 2;
  }
  if (paths.length > 1) {
    console.error('preflightkit: give one folder to check.');
    return 2;
  }
  const dir = folder(paths[0]);
  if (!dir) return 2;
  const bash = findBash();
  if (!bash) {
    console.error('preflightkit: the check needs bash. On Windows, install Git for Windows (https://git-scm.com) or use WSL.\n' +
      'If bash is installed somewhere unusual, set PREFLIGHTKIT_BASH to its path.');
    return 2;
  }
  const script = path.join(ROOT, 'scripts', 'security-check.sh');
  const r = spawnSync(bash, [script, ...options, dir], { stdio: 'inherit' });
  return r.status === null ? 1 : r.status;
}

// --- doctor ------------------------------------------------------------------

const PLATFORM = { win32: 'win', darwin: 'mac' }[process.platform] || 'linux';

const SCANNERS = [
  { cmd: 'gitleaks', what: 'leaked secrets in code and git history',
    install: { mac: 'brew install gitleaks', win: 'scoop install gitleaks',
      linux: 'https://github.com/gitleaks/gitleaks/releases' } },
  { cmd: 'semgrep', what: 'code flaws: injection, XSS, unsafe APIs',
    install: { mac: 'brew install semgrep', win: 'pipx install semgrep  (or run the check in WSL)',
      linux: 'pipx install semgrep' } },
  { cmd: 'trivy', what: 'vulnerable dependencies, secrets, misconfigurations',
    install: { mac: 'brew install trivy', win: 'scoop install trivy',
      linux: 'https://trivy.dev/latest/getting-started/installation/' } },
  { cmd: 'rg', what: 'faster pattern check (optional)',
    install: { mac: 'brew install ripgrep', win: 'scoop install ripgrep', linux: 'sudo apt install ripgrep' } },
];

const AUDITORS = [
  { marker: ['package-lock.json'], cmd: 'npm', name: 'npm audit', install: 'https://nodejs.org' },
  { marker: ['pnpm-lock.yaml'], cmd: 'pnpm', name: 'pnpm audit', install: 'npm install -g pnpm' },
  { marker: ['yarn.lock'], cmd: 'yarn', name: 'yarn audit', install: 'corepack enable' },
  { marker: ['composer.lock'], cmd: 'composer', name: 'composer audit', install: 'https://getcomposer.org' },
  { marker: ['requirements.txt', 'pyproject.toml'], cmd: 'pip-audit', name: 'pip-audit', install: 'pipx install pip-audit' },
  { marker: ['go.mod'], cmd: 'govulncheck', name: 'govulncheck', install: 'go install golang.org/x/vuln/cmd/govulncheck@latest' },
  { marker: ['Gemfile.lock'], cmd: 'bundle-audit', name: 'bundle-audit', install: 'gem install bundler-audit' },
  { marker: ['.csproj', '.sln'], cmd: 'dotnet', name: 'dotnet vulnerable-package check', install: 'https://dot.net' },
];

function doctor(target) {
  const dir = folder(target);
  if (!dir) return 2;
  const row = (found, name, detail) =>
    console.log(`  ${found ? '[found]  ' : '[missing]'} ${name.padEnd(12)} ${detail}`);

  console.log(`PreflightKit doctor: ${dir}\n`);
  const bash = findBash();
  row(Boolean(bash), 'bash', bash ? `runs the check (${bash})` :'needed to run the check. Install Git for Windows: https://git-scm.com');

  console.log('\nScanners:');
  let core = 0;
  for (const s of SCANNERS) {
    const found = which(s.cmd);
    if (found && s.cmd !== 'rg') core++;
    row(Boolean(found), s.cmd, found ? s.what : `${s.what}\n${' '.repeat(25)}install: ${s.install[PLATFORM]}`);
  }

  const files = fs.readdirSync(dir);
  const auditors = AUDITORS.filter((a) => a.marker.some((m) =>
    m.startsWith('.') ? files.some((f) => f.endsWith(m)) : files.includes(m)));
  console.log('\nDependency auditors for this project:');
  if (auditors.length === 0) console.log('  none needed (no lockfile found). Trivy still scans dependencies.');
  for (const a of auditors) {
    const found = which(a.cmd);
    row(Boolean(found), a.cmd, found ? a.name : `${a.name}\n${' '.repeat(25)}install: ${a.install}`);
  }

  console.log(`\n${core} of 3 core scanners installed.`);
  if (core < 3) {
    console.log('Missing scanners are skipped locally. The GitHub Action installs all of them for you:');
    console.log('  npx preflightkit init');
  }
  return 0;
}

// --- init --------------------------------------------------------------------

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
  console.log('To block deploys until it passes, see the comments at the end of the file.');
  console.log('\nTip: npx preflightkit rules  gives your AI coding assistant the same security rules.');
  return 0;
}

// --- rules -------------------------------------------------------------------

const START = '<!-- preflightkit:start -->';
const END = '<!-- preflightkit:end -->';

// block: a managed section inside a shared file. own: a file PreflightKit owns.
const RULE_TARGETS = {
  agents: { file: 'AGENTS.md', kind: 'block' },
  copilot: { file: path.join('.github', 'copilot-instructions.md'), kind: 'block' },
  cursor: { file: path.join('.cursor', 'rules', 'preflightkit.mdc'), kind: 'own',
    header: '---\ndescription: PreflightKit secure-coding guardrails\nalwaysApply: true\n---\n\n' },
  claude: { file: 'CLAUDE.md', kind: 'block' },
  windsurf: { file: path.join('.windsurf', 'rules', 'preflightkit.md'), kind: 'own',
    header: '---\ntrigger: always_on\n---\n\n' },
};
const DEFAULT_RULE_TARGETS = ['agents', 'copilot', 'cursor'];

function rulesText() {
  const skill = fs.readFileSync(
    path.join(ROOT, 'plugins', 'preflightkit', 'skills', 'secure-coding', 'SKILL.md'), 'utf8');
  const body = skill.replace(/\r\n/g, '\n').replace(/^---\n[\s\S]*?\n---\n/, '').trim();
  return [
    `<!-- Added by PreflightKit ${pkg.version} (${REPO}). Re-run \`npx preflightkit rules\` to update. -->`,
    '',
    body,
    '',
    '## Before you deploy',
    'Run `npx preflightkit` and fix every `[fail]` result. `[warn]` results are',
    'advisory: check each one. `[error]` means a scanner did not run, so that part',
    'was not checked. Do not add suppressions or lower the audit level without the',
    "user's agreement.",
  ].join('\n');
}

function rules(args) {
  const force = args.includes('--force');
  const names = args.filter((a) => a !== '--force').map((a) => a.replace(/^--/, ''));
  const bad = names.find((n) => n !== 'all' && !RULE_TARGETS[n]);
  if (bad) {
    console.error(`preflightkit: unknown rules target "${bad}". Use --agents, --copilot, --cursor, --claude, --windsurf or --all.`);
    return 2;
  }
  const targets = names.includes('all') ? Object.keys(RULE_TARGETS)
    : names.length ? names : DEFAULT_RULE_TARGETS;
  const section = `${START}\n${rulesText()}\n${END}\n`;
  let status = 0;

  for (const name of targets) {
    const t = RULE_TARGETS[name];
    const dest = path.join(process.cwd(), t.file);
    const existing = fs.existsSync(dest) ? fs.readFileSync(dest, 'utf8') : null;
    let next;
    let verb;
    if (t.kind === 'own') {
      if (existing !== null && !existing.includes(START) && !force) {
        console.error(`Skipped ${t.file}: it exists and wasn't made by PreflightKit. Use --force to overwrite.`);
        status = 1;
        continue;
      }
      next = t.header + section;
      verb = existing === null ? 'Created' : 'Updated';
    } else if (existing === null) {
      next = section;
      verb = 'Created';
    } else {
      const i = existing.indexOf(START);
      const j = existing.indexOf(END);
      if (i >= 0 && j > i) {
        next = existing.slice(0, i) + section.trimEnd() + existing.slice(j + END.length);
        verb = 'Updated';
      } else {
        next = `${existing.trimEnd()}\n\n${section}`;
        verb = 'Added rules to';
      }
    }
    if (next === existing) {
      console.log(`Up to date: ${t.file}`);
      continue;
    }
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, next);
    console.log(`${verb} ${t.file}`);
  }
  if (status === 0) console.log('\nCommit these files so everyone on the team, and every assistant, gets the same rules.');
  return status;
}

// --- checklist ---------------------------------------------------------------

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
    case 'rules':
      return rules(rest);
    case 'doctor':
      return doctor(rest[0]);
    case 'checklist':
      return checklist();
    case 'check':
      return check(rest);
    case undefined:
      return check([]);
    default:
      return check(argv);   // a path and/or check options
  }
}

process.exitCode = main(process.argv.slice(2));
