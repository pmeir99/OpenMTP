'use strict';

const { spawnSync } = require('child_process');
const isMacOS = process.platform === 'darwin';
const command = isMacOS ? 'swift' : './app/main.prod.js';
const args = isMacOS
  ? ['run', '--package-path', 'NativeMac', 'OpenMTPNative']
  : [];
const env = { ...process.env, NODE_ENV: 'production' };
const result = spawnSync(command, args, { stdio: 'inherit', env, shell: process.platform === 'win32' });

if (result.error) throw result.error;
process.exit(typeof result.status === 'number' ? result.status : 1);
