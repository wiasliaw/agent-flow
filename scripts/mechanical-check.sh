#!/bin/sh
# Mechanical checks that `claude plugin validate` cannot perform:
# 1. agents/*.md frontmatter must not contain the fields plugin agents do not
#    support or the design forbids: hooks, mcpServers, permissionMode,
#    skills, isolation — and must not grant the Agent tool.
# 2. references/ must contain all six files named by skills and dispatch prompts.
cd "$(dirname "$0")/.." || exit 1
exec python3 - <<'EOF'
import os, re, sys

ok = True

FORBIDDEN = {'hooks', 'mcpServers', 'permissionMode', 'skills', 'isolation'}
for path in ('agents/worker.md', 'agents/reviewer.md'):
    if not os.path.exists(path):
        print(f'FAIL: {path} missing'); ok = False; continue
    text = open(path).read()
    m = re.match(r'^---\n(.*?)\n---\n', text, re.S)
    if not m:
        print(f'FAIL: {path} has no parseable frontmatter'); ok = False; continue
    fm = m.group(1)
    keys = {k.group(1) for k in re.finditer(r'^([A-Za-z][\w-]*):', fm, re.M)}
    bad = keys & FORBIDDEN
    if bad:
        print(f'FAIL: {path} frontmatter contains forbidden field(s): {sorted(bad)}'); ok = False
    tools = re.search(r'^tools:(.*)$', fm, re.M)
    if tools and re.search(r'\bAgent\b', tools.group(1)):
        print(f'FAIL: {path} grants the Agent tool'); ok = False
    if not bad and not (tools and re.search(r'\bAgent\b', tools.group(1))):
        print(f'ok: {path}')

REFERENCES = ('glossary.md', 'state-management.md', 'sdd-guide.md',
              'tdd-guide.md', 'dispatch.md', 'quality-loop.md')
for name in REFERENCES:
    path = os.path.join('references', name)
    if os.path.exists(path):
        print(f'ok: {path}')
    else:
        print(f'FAIL: {path} missing'); ok = False

sys.exit(0 if ok else 1)
EOF
