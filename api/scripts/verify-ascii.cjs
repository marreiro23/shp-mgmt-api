#!/usr/bin/env node
/*
  verify-ascii.cjs

  CommonJS verifier intended to run inside the CVE API folder which is configured
  as ESM (package.json has "type": "module").

  Enforces repository rule:
  - No emojis / accented / non-ASCII characters in:
    - JSON keys (configs, schemas)
    - JavaScript object keys that are string literals (e.g., res.json({ "Chave": ... }))
    - CSV header arrays commonly declared as `headers = [...]` or `headers: [...]`

  Notes:
  - UI display text (web/) is intentionally out-of-scope; run this only on backend folders.
  - We do NOT attempt to ban non-ASCII in all strings/comments (too many false positives).
*/

'use strict';

const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const args = {
    root: process.cwd(),
    service: 'unknown',
  };

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--root') {
      args.root = argv[++i];
      continue;
    }
    if (a === '--service') {
      args.service = argv[++i];
      continue;
    }
    if (a === '--help' || a === '-h') {
      args.help = true;
      continue;
    }
  }

  return args;
}

function hasNonAsciiChars(str) {
  for (let i = 0; i < str.length; i++) {
    if (str.charCodeAt(i) > 0x7f) return true;
  }
  return false;
}

function literalMayProduceNonAscii(literalContent) {
  if (hasNonAsciiChars(literalContent)) return true;

  // Detect escaped unicode that would render to non-ASCII at runtime.
  // \u00E7, \u{1F600}, etc.
  const u4 = /\\u([0-9a-fA-F]{4})/g;
  let m;
  while ((m = u4.exec(literalContent))) {
    const code = parseInt(m[1], 16);
    if (Number.isFinite(code) && code > 0x7f) return true;
  }

  const uBrace = /\\u\{([0-9a-fA-F]+)\}/g;
  while ((m = uBrace.exec(literalContent))) {
    const code = parseInt(m[1], 16);
    if (Number.isFinite(code) && code > 0x7f) return true;
  }

  return false;
}

function shouldSkipDir(dirName) {
  const skip = new Set([
    'node_modules',
    'coverage',
    'logs',
    '.git',
    '.vscode',
    '.idea',
    'dist',
    'build',
    'out',
  ]);
  return skip.has(dirName);
}

function walkFiles(rootDir) {
  const results = [];

  function walk(current) {
    let entries;
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (shouldSkipDir(entry.name)) continue;
        walk(fullPath);
        continue;
      }
      if (!entry.isFile()) continue;
      results.push(fullPath);
    }
  }

  walk(rootDir);
  return results;
}

function readText(filePath) {
  // Read as UTF-8 and strip a leading BOM (U+FEFF) if present.
  // JSON.parse fails when the BOM is present as the first character.
  let text = fs.readFileSync(filePath, 'utf8');
  if (text && text.charCodeAt(0) === 0xFEFF) {
    text = text.slice(1);
  }
  return text;
}

function analyzeJsonKeys(filePath, text) {
  const issues = [];
  let obj;
  try {
    obj = JSON.parse(text);
  } catch (e) {
    issues.push({
      filePath,
      kind: 'json-parse',
      message: `Invalid JSON: ${e.message}`,
    });
    return issues;
  }

  function visit(node, jsonPath) {
    if (node && typeof node === 'object') {
      if (Array.isArray(node)) {
        for (let i = 0; i < node.length; i++) visit(node[i], `${jsonPath}[${i}]`);
        return;
      }

      for (const key of Object.keys(node)) {
        if (literalMayProduceNonAscii(key)) {
          issues.push({
            filePath,
            kind: 'json-key',
            message: `Non-ASCII JSON key at ${jsonPath}.${key}`,
          });
        }
        visit(node[key], `${jsonPath}.${key}`);
      }
    }
  }

  visit(obj, '$');
  return issues;
}

function extractQuotedStrings(segment) {
  // Extract string literal contents for ' and " within a segment.
  const out = [];
  for (let i = 0; i < segment.length; i++) {
    const ch = segment[i];
    if (ch !== '"' && ch !== "'") continue;

    const quote = ch;
    let j = i + 1;
    let content = '';
    let escaped = false;

    for (; j < segment.length; j++) {
      const c = segment[j];
      if (escaped) {
        content += '\\' + c; // keep escapes in raw form
        escaped = false;
        continue;
      }
      if (c === '\\') {
        escaped = true;
        continue;
      }
      if (c === quote) break;
      content += c;
    }

    if (j < segment.length && segment[j] === quote) {
      out.push(content);
      i = j;
    }
  }
  return out;
}

function analyzeJsStringKeys(filePath, text) {
  const issues = [];

  // 1) Quoted object keys: "Key": value OR 'Key': value
  // We intentionally only check string-literal keys; banning non-ASCII in all identifiers
  // requires an AST parser.
  const keyRegex = /(["'])([^"'\\]*(?:\\.[^"'\\]*)*)\1\s*:/g;
  let m;
  while ((m = keyRegex.exec(text))) {
    const literal = m[2];
    if (literalMayProduceNonAscii(literal)) {
      issues.push({
        filePath,
        kind: 'js-string-key',
        message: `Non-ASCII string key detected: ${m[1]}${literal}${m[1]}`,
      });
    }
  }

  // 2) Header arrays: headers = [ ... ] OR headers: [ ... ]
  // We scan a limited region to reduce false positives.
  const headersRegex = /\bheaders\b\s*[:=]\s*\[/g;
  while ((m = headersRegex.exec(text))) {
    const start = m.index;
    const after = text.slice(start);
    const closeIdx = after.indexOf(']');
    if (closeIdx === -1) continue;

    const segment = after.slice(0, Math.min(closeIdx + 1, 8000));
    const strings = extractQuotedStrings(segment);

    for (const s of strings) {
      if (literalMayProduceNonAscii(s)) {
        issues.push({
          filePath,
          kind: 'csv-headers',
          message: `Non-ASCII header string detected near headers[]: "${s}"`,
        });
      }
    }
  }

  return issues;
}

function isTargetFile(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return ext === '.js' || ext === '.cjs' || ext === '.mjs' || ext === '.json';
}

function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    // Keep output ASCII-only.
    console.log('Usage: node scripts/verify-ascii.cjs --service <name> --root <path>');
    process.exit(0);
  }

  const rootAbs = path.resolve(args.root);
  if (!fs.existsSync(rootAbs)) {
    console.error(`[verify-ascii] Root path not found: ${rootAbs}`);
    process.exit(2);
  }

  const files = walkFiles(rootAbs).filter(isTargetFile);
  const issues = [];

  for (const filePath of files) {
    let text;
    try {
      text = readText(filePath);
    } catch (e) {
      issues.push({ filePath, kind: 'read', message: `Failed to read: ${e.message}` });
      continue;
    }

    const ext = path.extname(filePath).toLowerCase();
    if (ext === '.json') {
      issues.push(...analyzeJsonKeys(filePath, text));
    } else {
      issues.push(...analyzeJsStringKeys(filePath, text));
    }
  }

  if (issues.length > 0) {
    console.error(`[verify-ascii] FAIL (${args.service}): Found ${issues.length} issue(s)`);
    for (const issue of issues) {
      const rel = path.relative(rootAbs, issue.filePath);
      console.error(`- ${rel} [${issue.kind}] ${issue.message}`);
    }
    process.exit(1);
  }

  console.log(`[verify-ascii] OK (${args.service}): ${files.length} file(s) checked`);
}

main();
