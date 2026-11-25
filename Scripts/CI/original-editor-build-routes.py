#!/usr/bin/env python3
"""Stage qualified SDK inputs, configure an existing Host, or verify its built app."""
import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

import original_editor_sdk_routes as routes

ROOT = Path(__file__).resolve().parents[2]


def prepare_existing(evidence):
    hq = runpy.run_path(str(ROOT / 'Scripts/CI/hq-stage2-focused-apple.py'))
    # Keep the original functions and their shared globals; only choose a new
    # task-owned evidence directory, as their input-only route already does.
    hq['preflight'].__globals__['OUT'] = evidence
    config = json.loads((ROOT / 'Scripts/CI/hq-stage2-focused-apple.inputs.json').read_bytes())
    report = {'status': 'FAIL', 'app_build_executed': False, 'runtime': 'NOT_RUN', 'commands': []}
    try:
        report.update(hq['preflight'](config))
        capture = hq['capture']
        routes.require(sys.platform == 'darwin', 'Original Host SDK preparation requires the actual Mac')
        report.update(xcode=capture('xcodebuild', '-version'), swift=capture('xcrun', 'swiftc', '--version'),
                      sdk_path=capture('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'),
                      sdk_version=capture('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'),
                      developer_dir=os.environ.get('DEVELOPER_DIR') or capture('xcode-select', '-p'))
        vendor = ROOT / 'Vendor/SefariaMobile/Upstream'
        routes.require(capture('git', '-C', str(vendor), 'rev-parse', 'HEAD') == config['sefaria_gitlink'],
                       'Installed original React upstream differs')
        npm_lock = vendor / 'package-lock.json'
        routes.require(npm_lock.read_bytes() == subprocess.check_output(
            ['git', 'show', 'HEAD:package-lock.json'], cwd=vendor), 'Installed npm lock changed')
        report['native_context'] = {'gitlink': config['sefaria_gitlink'], 'npm_lock_sha256': routes.digest(npm_lock),
            'podfile_sha256': routes.digest(ROOT / 'Podfile'), 'node': capture('node', '--version'),
            'cocoapods': capture('pod', '--version'), 'ruby': capture('ruby', '--version')}
        hanlin = evidence / 'hanlin-sdk-inputs.json'
        hq['logged']([sys.executable, 'Scripts/CI/prepare-hanlin-sdk.py', '--sha', config['hanlin_gitlink'],
                      '--verify-only', '--output', str(hanlin)], 'hanlin-sdk-inputs.log', report)
        report['hanlin_sdk_source'] = json.loads(hanlin.read_bytes())
        # Reuse the real installed dependency inputs. No source archive, npm
        # checkout or compiler cache is restored over a prepared workspace.
        hq['install_real_pods'](report, original_editor=True)
        hq['verify_actual_sources'](report)
        hq['authorize_pinned_equatable_macro'](report)
        routes.prepare(ROOT, report, evidence, hq['logged'])
        report.update(status='QUALIFIED_SDK_ROUTES_CONFIGURED_BUILD_NOT_RUN', app_build_executed=False,
                      runtime='NOT_RUN', signing=False)
        return report
    except BaseException as error:
        report.update(error_type=type(error).__name__, error=str(error))
        raise
    finally:
        (evidence / 'result.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('stage', 'prepare-existing'):
        child = sub.add_parser(name)
        child.add_argument('--evidence', required=True)
    child = sub.add_parser('verify')
    child.add_argument('--configuration', required=True, choices=['Debug', 'Release'])
    child.add_argument('--platform', required=True, choices=['iphonesimulator', 'iphoneos'])
    child.add_argument('--app', required=True)
    child.add_argument('--routes', required=True)
    child.add_argument('--routes-sha256', required=True)
    child.add_argument('--after-ui', action='store_true')
    child.add_argument('--after-archive', action='store_true')
    args = parser.parse_args()
    if args.command in {'stage', 'prepare-existing'}:
        evidence = routes.owned(ROOT, args.evidence, 'build/')
        evidence.mkdir(parents=True, exist_ok=True)
        if args.command == 'stage':
            result = routes.stage(ROOT, routes.load(ROOT))
            (evidence / 'sdk-transport.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
        else:
            result = prepare_existing(evidence)
            if os.environ.get('GITHUB_OUTPUT'):
                with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
                    output.write('routes_sha256=' + result['original_editor_routes']['sha256'] + '\n')
                    output.write('routes_path=' + result['original_editor_routes']['path'] + '\n')
    else:
        app = Path(args.app)
        if not app.is_absolute():
            app = ROOT / app
        result = routes.verify(ROOT, args.routes, args.configuration, args.platform, app,
                               route_sha256=args.routes_sha256, after_ui=args.after_ui, after_archive=args.after_archive)
    print(json.dumps(result, indent=2, sort_keys=True))
