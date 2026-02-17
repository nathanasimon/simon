#!/usr/bin/env node

import { execSync } from "child_process";

function checkPython() {
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

const python = checkPython();
if (!python) {
  console.warn("\n⚠  Simon requires Python >= 3.11");
  console.warn("   Install it with: pacman -S python  (Arch) or brew install python (macOS)\n");
} else {
  console.log(`Simon: found ${python} ✓`);
}
