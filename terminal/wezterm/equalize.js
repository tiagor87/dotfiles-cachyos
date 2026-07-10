#!/usr/bin/env node
'use strict';

/**
 * equalize.js — evenly distribute WezTerm pane sizes within the current tab.
 *
 * Usage:
 *   node equalize.js [--tab-id N] [--tolerance N] [--dry-run]
 *
 * WezTerm CLI semantics (activate-pane required first):
 *   Right +M → active pane grows right by M,  RIGHT neighbor shrinks by M
 *   Left  +M → active pane shrinks by M,       RIGHT neighbor grows by M
 *   Down  +M → active pane grows down by M,    BOTTOM neighbor shrinks by M
 *   Up    +M → active pane shrinks by M,        BOTTOM neighbor grows by M
 */

const { spawnSync } = require('child_process');

function wt(...args) {
  const result = spawnSync('wezterm', ['cli', ...args], { encoding: 'utf8' });
  if (result.error) throw new Error(`wezterm cli failed: ${result.error.message}`);
  return result.stdout || '';
}

function listPanes() {
  const raw = wt('list', '--format', 'json');
  let panes;
  try {
    panes = JSON.parse(raw);
  } catch {
    process.stderr.write('failed to parse pane list: invalid JSON\n');
    process.exit(1);
  }
  if (!Array.isArray(panes)) {
    process.stderr.write('failed to parse pane list: expected JSON array\n');
    process.exit(1);
  }
  for (const p of panes) {
    for (const field of ['pane_id', 'tab_id', 'size']) {
      if (p[field] === undefined || p[field] === null) {
        process.stderr.write(`pane data schema error: missing field '${field}'\n`);
        process.exit(1);
      }
    }
    for (const dim of ['cols', 'rows']) {
      if (typeof p.size[dim] !== 'number' || p.size[dim] <= 0) {
        process.stderr.write(`pane data schema error: invalid size.${dim}\n`);
        process.exit(1);
      }
    }
  }
  return panes;
}

function getPaneById(id, all) {
  return (all || listPanes()).find(p => p.pane_id === id) || null;
}

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function activateAndAdjust(paneId, direction, amount) {
  if (amount <= 0) return;
  wt('activate-pane', '--pane-id', String(paneId));
  sleep(60);
  wt('adjust-pane-size', direction, '--amount', String(amount));
  sleep(60);
}

function groupByRow(panes, threshold = 3) {
  const sorted = [...panes].sort((a, b) => a.top_row - b.top_row);
  const rows = [];
  for (const p of sorted) {
    const existing = rows.find(r => Math.abs(r[0].top_row - p.top_row) <= threshold);
    if (existing) existing.push(p);
    else rows.push([p]);
  }
  return rows.map(r => r.sort((a, b) => a.left_col - b.left_col));
}

function equalizeWidths(row, tolerance, dryRun) {
  if (row.length <= 1) return;
  const total = row.reduce((s, p) => s + p.size.cols, 0);
  const target = Math.floor(total / row.length);

  process.stdout.write(
    `  cols [${row.map(p => p.size.cols).join(' | ')}]  →  target ${target} each\n`
  );

  if (dryRun) return;

  for (let i = 0; i < row.length - 1; i++) {
    let converged = false;
    for (let attempt = 0; attempt < 30; attempt++) {
      const cur = getPaneById(row[i].pane_id);
      if (!cur) break;
      const delta = target - cur.size.cols;
      if (Math.abs(delta) <= tolerance) { converged = true; break; }
      activateAndAdjust(row[i].pane_id, delta > 0 ? 'Right' : 'Left', Math.abs(delta));
    }
    if (!converged) {
      const cur = getPaneById(row[i].pane_id);
      const remaining = cur ? Math.abs(target - cur.size.cols) : '?';
      throw new Error(`pane ${row[i].pane_id} did not converge; remaining delta: ${remaining} cells`);
    }
  }

  const final = listPanes();
  process.stdout.write(
    `  done [${row.map(p => getPaneById(p.pane_id, final)?.size.cols ?? '?').join(' | ')}]\n`
  );
}

function equalizeHeights(rows, tolerance, dryRun) {
  if (rows.length <= 1) return;
  const total = rows.reduce((s, r) => s + r[0].size.rows, 0);
  const target = Math.floor(total / rows.length);

  process.stdout.write(
    `\nEqualizing heights:\n  rows [${rows.map(r => r[0].size.rows).join(' | ')}]  →  target ${target} each\n`
  );

  if (dryRun) return;

  for (let i = 0; i < rows.length - 1; i++) {
    let converged = false;
    for (let attempt = 0; attempt < 30; attempt++) {
      const cur = getPaneById(rows[i][0].pane_id);
      if (!cur) break;
      const delta = target - cur.size.rows;
      if (Math.abs(delta) <= tolerance) { converged = true; break; }
      activateAndAdjust(rows[i][0].pane_id, delta > 0 ? 'Down' : 'Up', Math.abs(delta));
    }
    if (!converged) {
      const cur = getPaneById(rows[i][0].pane_id);
      const remaining = cur ? Math.abs(target - cur.size.rows) : '?';
      throw new Error(`pane ${rows[i][0].pane_id} did not converge (height); remaining delta: ${remaining} cells`);
    }
  }
}

function parseArgs(argv) {
  const r = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const k = argv[i].slice(2);
      r[k] = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true;
    }
  }
  return r;
}

function validatePositiveInt(value, name) {
  if (!/^\d+$/.test(String(value)) || parseInt(value, 10) <= 0) {
    process.stderr.write(`${name} must be a positive integer\n`);
    process.exit(1);
  }
  return parseInt(value, 10);
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  const tolerance = args['tolerance'] !== undefined
    ? (() => {
        const v = parseInt(args['tolerance'], 10);
        if (isNaN(v) || v < 0 || v > 50) {
          process.stderr.write('tolerance must be between 0 and 50\n');
          process.exit(1);
        }
        return v;
      })()
    : 1;

  const dryRun = !!args['dry-run'];

  const myPaneId = parseInt(process.env.WEZTERM_PANE || '0', 10);
  if (!myPaneId) {
    process.stderr.write('WEZTERM_PANE is not set; run inside a WezTerm session\n');
    process.exit(1);
  }

  const all = listPanes();
  const myPane = all.find(p => p.pane_id === myPaneId);

  let tabId;
  if (args['tab-id'] !== undefined) {
    tabId = validatePositiveInt(args['tab-id'], 'tab-id');
    if (!all.some(p => p.tab_id === tabId)) {
      process.stderr.write(`tab ${tabId} not found\n`);
      process.exit(1);
    }
  } else {
    tabId = myPane?.tab_id;
  }

  const panes = all.filter(p => p.tab_id === tabId);
  if (!panes.length) {
    process.stderr.write(`no panes found for tab ${tabId}\n`);
    process.exit(1);
  }

  const rows = groupByRow(panes);
  process.stdout.write(`Tab ${tabId} — ${panes.length} pane(s) in ${rows.length} row(s)\n`);

  if (panes.length === 1) {
    process.stdout.write('nothing to equalize\n');
    process.exit(0);
  }

  if (dryRun) {
    rows.forEach((row, i) => {
      const total = row.reduce((s, p) => s + p.size.cols, 0);
      process.stdout.write(
        `  Row ${i + 1}: [${row.map(p => `pane${p.pane_id}:${p.size.cols}c`).join(' | ')}]` +
        `  →  target ${Math.floor(total / row.length)}\n`
      );
    });
    process.exit(0);
  }

  let exitCode = 0;
  try {
    process.stdout.write('\nEqualizing widths:\n');
    for (const row of rows) equalizeWidths(row, tolerance, false);

    if (rows.length > 1) {
      const refreshed = groupByRow(listPanes().filter(p => p.tab_id === tabId));
      equalizeHeights(refreshed, tolerance, false);
    }
  } catch (err) {
    process.stderr.write(`${err.message}\n`);
    exitCode = 1;
  } finally {
    wt('activate-pane', '--pane-id', String(myPaneId));
  }

  if (exitCode !== 0) process.exit(exitCode);
  process.stdout.write('\nDone.\n');
}

main();
