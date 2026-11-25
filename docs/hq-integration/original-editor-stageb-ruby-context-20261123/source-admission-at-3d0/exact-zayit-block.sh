python3 - <<'PY'
import json, os, pathlib
rebuild = json.loads(pathlib.Path('Scripts/CI/hq-stage2-focused-apple.inputs.json').read_text()).get('rebuild_zayit_framework', False)
assert type(rebuild) is bool
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write('rebuild=' + str(rebuild).lower() + '\n')
PY
