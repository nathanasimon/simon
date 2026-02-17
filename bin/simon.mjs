#!/usr/bin/env node

import { execFileSync, execSync } from "child_process";
import { existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const venvDir = join(root, ".venv");
const venvPython = join(venvDir, "bin", "python");
const args = process.argv.slice(2);

function findPython() {
  for (const cmd of ["python3.13", "python3.12", "python3.11", "python3"]) {
    try {
      const out = execSync(`${cmd} --version 2>&1`, { encoding: "utf8" });
      const match = out.match(/(\d+)\.(\d+)/);
      if (match && parseInt(match[1]) >= 3 && parseInt(match[2]) >= 11) {
        return cmd;
      }
    } catch {}
  }
  return null;
}

function ensureVenv() {
  if (existsSync(venvPython)) return;

  const python = findPython();
  if (!python) {
    console.error("Error: Python >= 3.11 is required but not found.");
    console.error("Install it with: pacman -S python  (or your system package manager)");
    process.exit(1);
  }

  console.log("Setting up Simon (first run)...");
  execSync(`${python} -m venv ${venvDir}`, { stdio: "inherit" });
  execSync(`${venvPython} -m pip install --quiet -e "${root}"`, { stdio: "inherit" });
  console.log("Done. Simon is ready.\n");
}

ensureVenv();

try {
  execFileSync(venvPython, ["-m", "simon.cli.main", ...args], {
    stdio: "inherit",
    cwd: process.cwd(),
  });
} catch (e) {
  process.exit(e.status || 1);
}
