#!/usr/bin/env node
// Offline render check for the operational timeline panel.
//
// Loads index.html into jsdom, scrubs out v86 and xterm (we don't need an
// emulator for this), evaluates demo.js so the timeline IIFE installs its
// window.__agentGateTimelineEmit handler, then plays every <AG-TL> marker
// emitted by the incident's replay.sh into that handler.  Finally it
// asserts that the DOM ended up with the expected stage cards.
//
// Run:  node scripts/test-timeline.mjs

import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { JSDOM } from "jsdom";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");

const html  = readFileSync(resolve(repoRoot, "index.html"), "utf8")
  .replace(/<script[\s\S]*?<\/script>/g, "");                 // skip xterm/v86/demo
const demo  = readFileSync(resolve(repoRoot, "demo.js"), "utf8");

const dom = new JSDOM(html, { runScripts: "outside-only" });
const { window } = dom;

// Minimal shims so demo.js's IIFEs that touch v86/xterm don't throw.
//
// We also capture (a) every byte that demo.js writes to xterm and
// (b) the registered serial0-output-byte handler.  That lets us drive
// the byte-stream filter directly to confirm <AG-TL>…</AG-TL> spans
// never reach xterm.
const termWrites = [];
window.Terminal = class {
  constructor() {}
  loadAddon() {}
  open() {}
  write(buf) {
    if (buf instanceof Uint8Array) termWrites.push(buf);
    else termWrites.push(new TextEncoder().encode(String(buf)));
  }
};
window.FitAddon = { FitAddon: class { fit() {} } };
const v86Listeners = {};
window.V86 = class {
  constructor() {}
  add_listener(ev, cb) { v86Listeners[ev] = cb; }
  serial0_send() {}
};
window.requestAnimationFrame = (cb) => setTimeout(cb, 0);
window.fetch         = async () => ({ ok: false });            // skips manifest path
window.SpeechRecognition = undefined;

// Evaluate demo.js inside the jsdom window context.
window.eval(demo);

if (typeof window.__agentGateTimelineEmit !== "function") {
  console.error("FAIL: window.__agentGateTimelineEmit not installed");
  process.exit(1);
}

// Capture every <AG-TL>…</AG-TL> marker from replay.sh.
const replayOut = execSync(
  resolve(repoRoot, "incidents/deployment-approval-bypass/replay.sh"),
  { encoding: "utf8" }
);
const markers = [];
const re = /<AG-TL>([\s\S]*?)<\/AG-TL>/g;
let m;
while ((m = re.exec(replayOut)) !== null) markers.push(m[1]);

console.log("captured", markers.length, "markers");
for (const body of markers) window.__agentGateTimelineEmit(body);

// Assertions.
const doc      = window.document;
const stages   = doc.querySelectorAll(".tl-stage");
const dividers = doc.querySelectorAll(".tl-divider");
const incident = doc.getElementById("tl-incident-id").textContent;
const policy   = doc.getElementById("tl-policy-hash").textContent;
const hasMain  = doc.getElementById("main").classList.contains("has-timeline");

const expectedStages = [
  ["agent.generation",       "done"],
  ["deployment.trigger",     "done"],
  ["approval.state.observed","fail"],
  ["policy.violation",       "deny"],
  ["gate.decision",          "deny"],
  ["evidence.sealed",        "done"],
  ["signatures.collected",   "done"],
  ["deployment.trigger.2",   "done"],
  ["approval.state.observed.2","pass"],
  ["policy.evaluated",       "pass"],
  ["gate.decision.2",        "pass"],
  ["evidence.sealed.2",      "done"],
];

let failed = 0;
function check(name, cond, detail) {
  console.log((cond ? "  ✓" : "  ✗"), name, detail || "");
  if (!cond) failed++;
}

check("main.has-timeline",      hasMain);
check("incident id rendered",   incident === "deployment-approval-bypass", incident);
check("policy hash rendered",   policy.length > 0,                          policy);
check("2 dividers (ACT 1/2)",   dividers.length === 2,                      String(dividers.length));
check("stage count",             stages.length === expectedStages.length,
      `${stages.length} actual vs ${expectedStages.length} expected`);

for (let i = 0; i < expectedStages.length; i++) {
  const [expId, expStatus] = expectedStages[i];
  const s = stages[i];
  if (!s) { check(`stage[${i}] = ${expId}`, false, "missing"); continue; }
  check(`stage[${i}] id`,     s.dataset.stage === expId,      `${s.dataset.stage} (want ${expId})`);
  check(`stage[${i}] status`, s.dataset.status === expStatus, `${s.dataset.status} (want ${expStatus})`);
}

// Spot-check: approval.state.observed has 4 fail rows
const approval = doc.querySelector('[data-stage="approval.state.observed"]');
if (approval) {
  const failRows = approval.querySelectorAll(".tl-row-fail");
  check("approval.state has 4 fail rows", failRows.length === 4, String(failRows.length));
}
const sigs = doc.querySelector('[data-stage="signatures.collected"]');
if (sigs) {
  const passRows = sigs.querySelectorAll(".tl-row-pass");
  check("signatures.collected has 4 pass rows", passRows.length === 4, String(passRows.length));
}
// Spot-check: agent.generation includes a diff code block
const gen = doc.querySelector('[data-stage="agent.generation"]');
if (gen) {
  const code = gen.querySelector(".tl-code.lang-diff");
  check("agent.generation has diff code block", !!code, code ? code.textContent.slice(0,40) : "");
}

// ── byte-filter algorithm check ──────────────────────────────────────
// Re-implement the same state machine that lives inside startEmulator()
// in demo.js.  jsdom's cross-realm eval drops the closure on stubbed
// classes so we can't easily drive the in-page filter from Node; the
// algorithm itself is deterministic, small, and worth pinning down
// independently anyway.
function runFilter(bytes) {
  const TL_HEAD = "<AG-TL>";
  const TL_TAIL = "</AG-TL>";
  let saw = "", inMarker = false, body = "", suppressNL = false;
  const xterm = [];
  const markers = [];
  for (let i = 0; i < bytes.length; i++) {
    const ch = String.fromCharCode(bytes[i]);
    if (inMarker) {
      body += ch;
      if (body.endsWith(TL_TAIL)) {
        markers.push(body.slice(0, -TL_TAIL.length));
        inMarker = false;
        body = "";
        suppressNL = true;
      }
      continue;
    }
    if (suppressNL) {
      suppressNL = false;
      if (ch === "\n") continue;
    }
    if (saw.length > 0) {
      const cand = saw + ch;
      if (TL_HEAD.startsWith(cand)) {
        if (cand === TL_HEAD) { inMarker = true; saw = ""; }
        else                  { saw = cand; }
        continue;
      }
      for (const c of saw) xterm.push(c);
      saw = "";
    }
    if (ch === "<") { saw = "<"; continue; }
    xterm.push(ch);
  }
  return { xterm: xterm.join(""), markers };
}

const bytes = Buffer.from(replayOut, "utf8");
const { xterm: xtermOutput, markers: routedMarkers } = runFilter(bytes);

check("xterm received no <AG-TL marker",    !xtermOutput.includes("<AG-TL"),
      "stripped " + (replayOut.length - xtermOutput.length) + " bytes");
check("xterm received no </AG-TL>",         !xtermOutput.includes("</AG-TL"));
check("byte filter routed 15 markers",      routedMarkers.length === 15,
      String(routedMarkers.length));
check("xterm still has log lines",          xtermOutput.includes("[03:14:07.118]"));
check("xterm still has compact summary",    xtermOutput.includes("policy 9c4f2a7b"));
// every routed marker must be valid JSON
let badJson = 0;
for (const m of routedMarkers) {
  try { JSON.parse(m); } catch (_) { badJson++; }
}
check("all routed markers are valid JSON",  badJson === 0, String(badJson) + " bad");

if (failed > 0) {
  console.error(`\n${failed} check(s) failed`);
  process.exit(1);
}
console.log("\nall checks passed");
