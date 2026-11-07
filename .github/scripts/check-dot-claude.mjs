// Is .claude/ what Claude Code reads, and only that?
//
// Three things a copied configuration gets wrong, each cheap to catch:
//
//   A SKILL.md without frontmatter, or without `name` and `description` in
//   it. Claude Code lists a skill by those two lines; a skill missing them is
//   a directory nobody is offered.
//
//   An agent without the same two lines, for the same reason.
//
//   A settings.json that does not parse, or that carries a credential. This
//   repository is copied to other machines by definition, so a token in it is
//   a token on every one of them. The check is a name pattern over every
//   string in the file and refuses anything that looks like one; a false
//   positive costs a rename, a miss costs a secret.
//
// No dependencies, so it runs with the node the workflow set up and nothing
// installed. Exits 1 with every failure listed, not the first.

import { readdirSync, readFileSync, existsSync, statSync } from 'node:fs';
import path from 'node:path';

const ROOT = process.argv[2] || '.claude';
let failures = 0;
const fail = (where, what) => {
  console.error(`  ${where}\n    ${what}`);
  failures++;
};

/** The YAML frontmatter of a markdown file, as flat key: value lines. */
function frontmatter(file) {
  const text = readFileSync(file, 'utf8');
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---(\r?\n|$)/);
  if (!m) return null;
  const out = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z][\w-]*):\s*(.*)$/);
    if (kv) out[kv[1]] = kv[2].trim();
  }
  return out;
}

function needs(file, keys) {
  const fm = frontmatter(file);
  if (!fm) return fail(file, 'has no frontmatter: it needs a block between --- lines with name and description');
  for (const k of keys) if (!fm[k]) fail(file, `frontmatter has no ${k}`);
}

const dirs = (p) => (existsSync(p) ? readdirSync(p).filter((d) => statSync(path.join(p, d)).isDirectory()) : []);
const files = (p, ext) => (existsSync(p) ? readdirSync(p).filter((f) => f.endsWith(ext)) : []);

// skills/<name>/SKILL.md
for (const skill of dirs(path.join(ROOT, 'skills'))) {
  const file = path.join(ROOT, 'skills', skill, 'SKILL.md');
  if (!existsSync(file)) {
    fail(path.join(ROOT, 'skills', skill), 'has no SKILL.md, so it is not a skill');
    continue;
  }
  needs(file, ['name', 'description']);
  const fm = frontmatter(file);
  if (fm?.name && fm.name !== skill) fail(file, `name is "${fm.name}" but the directory is "${skill}"; they should agree`);
}

// agents/<name>.md
for (const f of files(path.join(ROOT, 'agents'), '.md')) needs(path.join(ROOT, 'agents', f), ['name', 'description']);

// commands/<name>.md — frontmatter is optional for a command, but if it is
// there, a description is what the picker shows.
for (const f of files(path.join(ROOT, 'commands'), '.md')) {
  const file = path.join(ROOT, 'commands', f);
  const fm = frontmatter(file);
  if (fm && !fm.description) fail(file, 'has frontmatter without a description');
}

// settings.json
const settings = path.join(ROOT, 'settings.json');
if (existsSync(settings)) {
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(settings, 'utf8'));
  } catch (e) {
    fail(settings, `is not JSON: ${e.message}`);
  }
  if (parsed) {
    const SECRET = /(token|secret|password|passwd|api[_-]?key|private[_-]?key|credential)/i;
    const LOOKS_LIKE_ONE = /^(gh[pousr]_|github_pat_|sk-|xox[abp]-|AKIA|eyJ)[A-Za-z0-9_-]{8,}/;
    const walk = (v, at) => {
      if (Array.isArray(v)) return v.forEach((x, i) => walk(x, `${at}[${i}]`));
      if (v && typeof v === 'object') {
        for (const [k, x] of Object.entries(v)) {
          if (SECRET.test(k) && typeof x === 'string' && x.length > 0) fail(settings, `${at}.${k} names a credential; this file is copied to every machine`);
          walk(x, `${at}.${k}`);
        }
        return;
      }
      if (typeof v === 'string' && LOOKS_LIKE_ONE.test(v)) fail(settings, `${at} looks like a credential`);
    };
    walk(parsed, 'settings');
    if (parsed.env && typeof parsed.env === 'object') {
      for (const k of Object.keys(parsed.env)) if (SECRET.test(k)) fail(settings, `env.${k} would put a credential in every session's environment`);
    }
  }
}

if (failures) {
  console.error(`\n${failures} problem${failures === 1 ? '' : 's'} in ${ROOT}`);
  process.exit(1);
}
console.log(`${ROOT} has the shape Claude Code reads`);
