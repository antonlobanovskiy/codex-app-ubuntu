#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const appDir = process.argv[2];

if (!appDir) {
  console.error('usage: node scripts/patch-main.js /path/to/extracted/app');
  process.exit(2);
}

function fail(message) {
  console.error(`patch-main: ${message}`);
  process.exit(1);
}

function findMainBundle(root) {
  const buildDir = path.join(root, '.vite', 'build');
  if (!fs.existsSync(buildDir)) {
    fail(`missing build directory: ${buildDir}`);
  }
  const candidates = fs
    .readdirSync(buildDir)
    .filter((name) => /^main-.*\.js$/.test(name))
    .map((name) => path.join(buildDir, name));
  if (candidates.length !== 1) {
    fail(`expected one main-*.js bundle in ${buildDir}, found ${candidates.length}`);
  }
  return candidates[0];
}

function replaceOnce(source, name, from, to) {
  if (source.includes(to)) {
    console.log(`already patched: ${name}`);
    return source;
  }
  const count = source.split(from).length - 1;
  if (count !== 1) {
    fail(`${name}: expected one match, found ${count}`);
  }
  console.log(`patched: ${name}`);
  return source.replace(from, to);
}

const mainPath = findMainBundle(appDir);
let source = fs.readFileSync(mainPath, 'utf8');

source = replaceOnce(
  source,
  'linux opaque window background',
  ':e===`win32`&&!S9(t)?{backgroundColor:X7,backgroundMaterial:`mica`}:{backgroundColor:X7,backgroundMaterial:null}}function k9',
  ':e===`win32`&&!S9(t)?{backgroundColor:X7,backgroundMaterial:`mica`}:e===`linux`&&!S9(t)?{backgroundColor:r?Z7:Q7,backgroundMaterial:null}:{backgroundColor:X7,backgroundMaterial:null}}function k9',
);

source = replaceOnce(
  source,
  'linux managed primary and hotkey windows',
  'case`hotkeyWindowHome`:return A9({platform:n,resizable:!1,thickFrame:!1});case`hotkeyWindowThread`:return A9({platform:n,resizable:!0});case`primary`:return n===`darwin`?t?{titleBarStyle:`hiddenInset`,trafficLightPosition:d9(r)}:{vibrancy:`menu`,titleBarStyle:`hiddenInset`,trafficLightPosition:d9(r)}:n===`win32`||n===`linux`?{titleBarStyle:`hidden`,titleBarOverlay:f9(r)}:{titleBarStyle:`default`};',
  'case`hotkeyWindowHome`:return n===`linux`?{titleBarStyle:`default`,skipTaskbar:!1,minimizable:!0,maximizable:!0,fullscreenable:!0,resizable:!0}:A9({platform:n,resizable:!1,thickFrame:!1});case`hotkeyWindowThread`:return n===`linux`?{titleBarStyle:`default`,skipTaskbar:!1,minimizable:!0,maximizable:!0,fullscreenable:!0,resizable:!0}:A9({platform:n,resizable:!0});case`primary`:return n===`linux`?{frame:!0,skipTaskbar:!1,minimizable:!0,maximizable:!0,fullscreenable:!0,resizable:!0,transparent:!1}:n===`darwin`?t?{titleBarStyle:`hiddenInset`,trafficLightPosition:d9(r)}:{vibrancy:`menu`,titleBarStyle:`hiddenInset`,trafficLightPosition:d9(r)}:n===`win32`?{titleBarStyle:`hidden`,titleBarOverlay:f9(r)}:{titleBarStyle:`default`};',
);

source = replaceOnce(
  source,
  'omit undefined focusable option',
  'backgroundColor:A,show:l,parent:p,focusable:m,...process.platform===`win32`||process.platform===`linux`?{autoHideMenuBar:!0}:{}',
  'backgroundColor:A,show:l,parent:p,...m===void 0?{}:{focusable:m},...process.platform===`win32`||process.platform===`linux`?{autoHideMenuBar:!0}:{}',
);

source = replaceOnce(
  source,
  'titlebar overlay only on Windows',
  'installApplicationMenuTitleBarOverlaySync(e,t){if(process.platform!==`win32`&&process.platform!==`linux`||t!==`primary`)return;',
  'installApplicationMenuTitleBarOverlaySync(e,t){if(process.platform!==`win32`||t!==`primary`)return;',
);

source = replaceOnce(
  source,
  'window zoom overlay only on Windows',
  'process.platform===`darwin`?n.setWindowButtonPosition(d9(t)):(process.platform===`win32`||process.platform===`linux`)&&(this.windowZooms.set(n.id,t),n.setTitleBarOverlay(f9(t)))',
  'process.platform===`darwin`?n.setWindowButtonPosition(d9(t)):process.platform===`win32`&&(this.windowZooms.set(n.id,t),n.setTitleBarOverlay(f9(t)))',
);

source = replaceOnce(
  source,
  'do not force-center Linux onboarding window',
  'n.setResizable(!1),n.setMaximizable(!1),n.setFullScreenable(!1),n.setMinimumSize(i.width,i.height),n.setSize(i.width,i.height),n.center(),this.showPrimaryWindow(n);return',
  'process.platform===`linux`?(n.setResizable(!0),n.setMaximizable(!0),n.setFullScreenable(!0),n.setMinimumSize(Math.min(i.width,480),Math.min(i.height,600)),n.setSize(i.width,i.height)): (n.setResizable(!1),n.setMaximizable(!1),n.setFullScreenable(!1),n.setMinimumSize(i.width,i.height),n.setSize(i.width,i.height),n.center()),this.showPrimaryWindow(n);return',
);

source = replaceOnce(
  source,
  'hotkey windows stay on current Linux workspace',
  'process.platform===`darwin`?e.setVisibleOnAllWorkspaces(!0,{visibleOnFullScreen:!0,skipTransformProcessType:!0}):e.setVisibleOnAllWorkspaces(!0)),e.moveTop())}showAndFocus',
  'process.platform===`darwin`?e.setVisibleOnAllWorkspaces(!0,{visibleOnFullScreen:!0,skipTransformProcessType:!0}):process.platform===`linux`?e.setVisibleOnAllWorkspaces(!1):e.setVisibleOnAllWorkspaces(!0)),process.platform!==`linux`&&e.moveTop())}showAndFocus',
);

fs.writeFileSync(mainPath, source);
console.log(`wrote ${mainPath}`);
