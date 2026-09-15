"""Verify that Fish exports the shared defaults used by the real fzf."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class FzfDefaultsTest(unittest.TestCase):
    def test_fish_uses_shared_file_instead_of_inherited_inline_defaults(self):
        fish = shutil.which('fish')
        if not fish or not shutil.which('fzf'):
            self.skipTest('fish and fzf are required')

        with tempfile.TemporaryDirectory(prefix='fzf-defaults-') as directory:
            config = Path(directory) / '.config/fzf/config'
            config.parent.mkdir(parents=True)
            shutil.copyfile(ROOT / 'fzf/.config/fzf/config', config)
            env = dict(os.environ, HOME=directory,
                       FZF_DEFAULT_OPTS='--filter=stale-defaults',
                       FZF_DEFAULT_OPTS_FILE='/missing/old-config')
            result = subprocess.run([
                fish, '--no-config', '-c',
                'source $argv[1]; or exit $status; '
                'if set -q FZF_DEFAULT_OPTS; exit 1; end; '
                'printf "%s\\n" "$FZF_DEFAULT_OPTS_FILE"; '
                'printf "%s\\n" "shared defaults" | '
                'command fzf --no-popup --filter "shared defaults"',
                str(ROOT / 'fish/.config/fish/conf.d/exports.fish'),
            ], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), [str(config), 'shared defaults'])


if __name__ == '__main__':
    unittest.main()
