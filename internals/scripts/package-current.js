'use strict';

const { spawnSync } = require('child_process');
const isMacOS = process.platform === 'darwin';
const buildAll = process.argv.includes('--all');

const run = (command, args) => {
  const result = spawnSync(command, args, { stdio: 'inherit', shell: process.platform === 'win32' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
};

if (isMacOS) {
  run('bash', ['NativeMac/Scripts/package-macos.sh']);
  if (buildAll) {
    run('yarn', ['build']);
    run('yarn', ['electron-builder', '--config', 'electron-builder-config.js', 'build', '--linux', '--win', '--publish', 'never']);
  }
} else {
  run('yarn', ['build']);
  run('yarn', [
    'electron-builder',
    '--config', 'electron-builder-config.js',
    'build',
    ...(buildAll ? ['-mwl'] : []),
    '--publish', 'never',
  ]);
}
