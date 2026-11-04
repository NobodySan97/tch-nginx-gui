"""Deterministic full-suite fail-name collector: writes post_names.txt names sorted."""
import io, os, sys, unittest
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests'))
os.chdir(ROOT)

loader = unittest.TestLoader()
suite = loader.discover(str(ROOT / 'tests'), top_level_dir=str(ROOT / 'tests'))
runner = unittest.TextTestRunner(stream=io.StringIO(), verbosity=0)
result = runner.run(suite)

names = sorted(
    f[0].id() for f in result.failures + result.errors
)
out = Path(os.environ.get('OUT_FILE', 'post_names.txt'))
out.write_text('\n'.join(names) + '\n', encoding='utf-8')
print(f'tests={result.testsRun} failures={len(result.failures)} errors={len(result.errors)} skipped={len(result.skipped)}')
print(f'written={out}')
