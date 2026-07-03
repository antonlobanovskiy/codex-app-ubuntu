#!/usr/bin/env node
'use strict';

const Module = require('node:module');
const fs = require('node:fs');
const path = require('node:path');
const util = require('node:util');
const vm = require('node:vm');

const VERSION = 'codex-app-ubuntu-node-repl-shim-1';
const DEFAULT_TIMEOUT_MS = 120_000;
const MAX_OUTPUT_CHARS = 1_000_000;

let framing = 'line';
let moduleDirs = [];
let context = createContext();

function createContext() {
  const logs = [];
  const consoleProxy = {};
  for (const level of ['log', 'info', 'warn', 'error', 'debug']) {
    consoleProxy[level] = (...args) => {
      logs.push(args.map((arg) => format(arg)).join(' '));
    };
  }

  const sandbox = {
    Buffer,
    URL,
    URLSearchParams,
    TextDecoder,
    TextEncoder,
    AbortController,
    AbortSignal,
    atob,
    btoa,
    clearImmediate,
    clearInterval,
    clearTimeout,
    console: consoleProxy,
    fetch,
    global: null,
    globalThis: null,
    module,
    process,
    queueMicrotask,
    require,
    setImmediate,
    setInterval,
    setTimeout,
    __codexLogs: logs,
    __dirname: process.cwd(),
    __filename: path.join(process.cwd(), 'node_repl_input.js'),
  };
  sandbox.global = sandbox;
  sandbox.globalThis = sandbox;
  return vm.createContext(sandbox, { name: 'codex-node-repl' });
}

function format(value) {
  if (typeof value === 'string') {
    return value;
  }
  return util.inspect(value, {
    colors: false,
    depth: 8,
    maxArrayLength: 200,
    breakLength: 120,
  });
}

function truncate(text) {
  if (text.length <= MAX_OUTPUT_CHARS) {
    return text;
  }
  return `${text.slice(0, MAX_OUTPUT_CHARS)}\n... truncated ...`;
}

function send(message) {
  const body = JSON.stringify(message);
  if (framing === 'header') {
    process.stdout.write(`Content-Length: ${Buffer.byteLength(body, 'utf8')}\r\n\r\n${body}`);
  } else {
    process.stdout.write(`${body}\n`);
  }
}

function result(id, value) {
  send({ jsonrpc: '2.0', id, result: value });
}

function error(id, code, message, data) {
  send({ jsonrpc: '2.0', id, error: { code, message, ...(data === undefined ? {} : { data }) } });
}

function toolError(message) {
  return { isError: true, content: [{ type: 'text', text: message }] };
}

function normalizeTimeout(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_TIMEOUT_MS;
  }
  return Math.min(Math.max(1, Math.floor(parsed)), 10 * 60 * 1000);
}

function addModuleDir(dir) {
  if (!path.isAbsolute(dir)) {
    throw new Error('path must be absolute');
  }
  if (!fs.existsSync(dir)) {
    throw new Error(`path does not exist: ${dir}`);
  }
  if (!moduleDirs.includes(dir)) {
    moduleDirs.unshift(dir);
  }
  process.env.NODE_PATH = moduleDirs.join(path.delimiter);
  Module._initPaths();
}

async function runJavaScript(code, timeoutMs) {
  const logs = context.__codexLogs;
  logs.length = 0;

  let scriptSource = `(async () => (${code}\n))()`;
  let script;
  try {
    script = new vm.Script(scriptSource, { filename: 'node_repl_input.js' });
  } catch {
    scriptSource = `(async () => {\n${code}\n})()`;
    script = new vm.Script(scriptSource, { filename: 'node_repl_input.js' });
  }

  let timedOut = false;
  const timeout = new Promise((_, reject) => {
    setTimeout(() => {
      timedOut = true;
      reject(new Error(`js execution timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  const value = await Promise.race([
    script.runInContext(context, { timeout: Math.min(timeoutMs, 30_000) }),
    timeout,
  ]);

  if (timedOut) {
    throw new Error(`js execution timed out after ${timeoutMs}ms`);
  }

  const output = [];
  if (logs.length > 0) {
    output.push(logs.join('\n'));
  }
  if (value !== undefined) {
    output.push(format(value));
  }

  const response = {
    ok: true,
    output: truncate(output.join('\n')),
  };

  if (value && typeof value === 'object') {
    if (Array.isArray(value.images)) {
      response.images = value.images;
    }
    if (value.response_meta || value.responseMeta) {
      response.responseMeta = value.response_meta || value.responseMeta;
    }
    if (typeof value.output === 'string') {
      response.output = truncate(value.output);
    }
  }

  return response;
}

const tools = [
  {
    name: 'js',
    description: 'Run JavaScript in a persistent Node.js session. Supports top-level await.',
    inputSchema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        code: { type: 'string' },
        timeout_ms: { type: 'number' },
      },
      required: ['code'],
    },
  },
  {
    name: 'js_reset',
    description: 'Reset the persistent JavaScript session.',
    inputSchema: {
      type: 'object',
      additionalProperties: false,
      properties: {},
    },
  },
  {
    name: 'js_add_node_module_dir',
    description: 'Add an absolute node_modules directory to Node.js module resolution.',
    inputSchema: {
      type: 'object',
      additionalProperties: false,
      properties: { path: { type: 'string' } },
      required: ['path'],
    },
  },
];

async function handleToolCall(params) {
  const name = params && typeof params.name === 'string' ? params.name : '';
  const args = params && params.arguments && typeof params.arguments === 'object' ? params.arguments : {};

  if (name === 'js_reset') {
    context = createContext();
    return { content: [{ type: 'text', text: 'js session reset' }] };
  }

  if (name === 'js_add_node_module_dir') {
    try {
      addModuleDir(String(args.path || ''));
      return { content: [{ type: 'text', text: `added node module directory: ${args.path}` }] };
    } catch (err) {
      return toolError(err.message);
    }
  }

  if (name === 'js') {
    const code = typeof args.code === 'string' ? args.code : '';
    if (!code) {
      return toolError('js requires code');
    }
    try {
      const response = await runJavaScript(code, normalizeTimeout(args.timeout_ms));
      const content = [];
      if (response.output || !response.images || response.images.length === 0) {
        content.push({ type: 'text', text: response.output || '' });
      }
      for (const image of response.images || []) {
        if (image && image.data && image.mimeType) {
          content.push({ type: 'image', data: image.data, mimeType: image.mimeType });
        }
      }
      return {
        content,
        ...(response.responseMeta
          ? { response_meta: response.responseMeta, _meta: { response_meta: response.responseMeta } }
          : {}),
      };
    } catch (err) {
      return toolError(err && err.stack ? err.stack : String(err));
    }
  }

  return toolError(`unknown tool: ${name || '<missing>'}`);
}

async function handle(message) {
  if (!message || message.jsonrpc !== '2.0') {
    return;
  }
  const hasId = Object.prototype.hasOwnProperty.call(message, 'id');

  try {
    switch (message.method) {
      case 'initialize':
        if (hasId) {
          result(message.id, {
            protocolVersion: message.params?.protocolVersion || '2024-11-05',
            serverInfo: { name: 'codex-node-repl-linux', version: VERSION },
            capabilities: { tools: {} },
          });
        }
        break;
      case 'notifications/initialized':
        break;
      case 'ping':
        if (hasId) result(message.id, {});
        break;
      case 'tools/list':
        if (hasId) result(message.id, { tools });
        break;
      case 'tools/call':
        if (hasId) result(message.id, await handleToolCall(message.params));
        break;
      default:
        if (hasId) error(message.id, -32601, `method not found: ${message.method}`);
    }
  } catch (err) {
    if (hasId) {
      error(message.id, -32603, err && err.stack ? err.stack : String(err));
    }
  }
}

function readMessages(input, onMessage) {
  let buffer = Buffer.alloc(0);

  input.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    while (buffer.length > 0) {
      const text = buffer.toString('utf8');
      if (/^Content-Length:/i.test(text)) {
        const headerEnd = text.indexOf('\r\n\r\n');
        if (headerEnd === -1) return;
        const header = text.slice(0, headerEnd);
        const match = header.match(/Content-Length:\s*(\d+)/i);
        if (!match) {
          buffer = Buffer.alloc(0);
          return;
        }
        const length = Number(match[1]);
        const bodyStart = Buffer.byteLength(text.slice(0, headerEnd + 4), 'utf8');
        if (buffer.length < bodyStart + length) return;
        const body = buffer.slice(bodyStart, bodyStart + length).toString('utf8');
        buffer = buffer.slice(bodyStart + length);
        framing = 'header';
        onMessage(JSON.parse(body));
        continue;
      }

      const newline = buffer.indexOf(10);
      if (newline === -1) return;
      const line = buffer.slice(0, newline).toString('utf8').trim();
      buffer = buffer.slice(newline + 1);
      framing = 'line';
      if (line) {
        onMessage(JSON.parse(line));
      }
    }
  });
}

readMessages(process.stdin, (message) => {
  void handle(message);
});
