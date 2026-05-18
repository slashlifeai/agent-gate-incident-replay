#!/usr/bin/env node
// Build a v86 9p filesystem image from incidents/.
//
// Writes:
//   fs9p/<sha256-hex>        content-addressed file blobs
//   fs9p.json                v86 filesystem manifest (format version 3)
//
// v86 mounts this as a virtio-9p device tagged "host9p" inside the guest:
//   mount -t 9p -o trans=virtio,version=9p2000.L host9p /mnt/incident
//
// The manifest format is derived from libv86's LoadRecursive:
//   [name, size, mtime, mode, uid, gid, payload]
//   payload is:
//     - children array      (directory; mode &  0o170000 === S_IFDIR  = 0o40000)
//     - sha256 hex string   (regular file; mode & 0o170000 === S_IFREG = 0o100000)
//     - symlink target      (symlink; mode & 0o170000 === S_IFLNK = 0o120000)
//
// Re-run safe: blobs whose content hash already matches are not rewritten.

import { readdirSync, statSync, readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import { dirname, resolve, join, relative } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");
const srcRoot  = resolve(repoRoot, "incidents");
const outDir   = resolve(repoRoot, "fs9p");
const outJson  = resolve(repoRoot, "fs9p.json");

const S_IFDIR  = 0o40000;
const S_IFREG  = 0o100000;
const S_IFLNK  = 0o120000;

const DEFAULT_DIR_MODE  = S_IFDIR  | 0o755;
const DEFAULT_FILE_MODE = S_IFREG  | 0o644;
const EXEC_FILE_MODE    = S_IFREG  | 0o755;

if (!existsSync(srcRoot)) {
  console.error("incidents/ not found at", srcRoot);
  process.exit(1);
}
mkdirSync(outDir, { recursive: true });

let totalSize = 0;
let fileCount = 0;
let blobReused = 0;

function isExecutable(name, mode) {
  return name.endsWith(".sh") || (mode & 0o111) !== 0;
}

function walk(absPath) {
  const stat = statSync(absPath);
  const name = absPath === srcRoot ? "" : absPath.split("/").pop();
  const mtime = Math.floor(stat.mtimeMs / 1000);

  if (stat.isDirectory()) {
    const entries = readdirSync(absPath)
      .filter(n => !n.startsWith(".") && n !== "node_modules")
      .sort()
      .map(n => walk(join(absPath, n)));
    return [name, 0, mtime, DEFAULT_DIR_MODE, 0, 0, entries];
  }
  if (stat.isSymbolicLink()) {
    const target = require("fs").readlinkSync(absPath);
    return [name, target.length, mtime, S_IFLNK | 0o777, 0, 0, target];
  }
  if (stat.isFile()) {
    const buf = readFileSync(absPath);
    const sha = createHash("sha256").update(buf).digest("hex");
    const blobPath = join(outDir, sha);
    if (existsSync(blobPath)) blobReused++;
    else                      writeFileSync(blobPath, buf);
    const mode = isExecutable(absPath, stat.mode) ? EXEC_FILE_MODE : DEFAULT_FILE_MODE;
    totalSize += buf.length;
    fileCount++;
    return [name, buf.length, mtime, mode, 0, 0, sha];
  }
  throw new Error("unhandled fs entry: " + absPath);
}

// Root entry — v86's LoadRecursive treats fsroot as the children of "/"
// directly (it pushes each entry under parentid 0 = root), so we want to
// emit the contents of incidents/ as the top-level entries.
const rootChildren = readdirSync(srcRoot)
  .filter(n => !n.startsWith("."))
  .sort()
  .map(n => walk(join(srcRoot, n)));

const manifest = {
  version: 3,
  size: totalSize,
  fsroot: rootChildren,
};
writeFileSync(outJson, JSON.stringify(manifest));

console.log(`fs9p: ${fileCount} files, ${totalSize.toLocaleString()} bytes`);
console.log(`      ${blobReused} blob(s) reused, ${fileCount - blobReused} written`);
console.log(`      manifest: ${relative(repoRoot, outJson)}`);
console.log(`      blobs:    ${relative(repoRoot, outDir)}/`);
