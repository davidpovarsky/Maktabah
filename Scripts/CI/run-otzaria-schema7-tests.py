#!/usr/bin/env python3
"""Compile and execute real SQLite fixture tests against production Swift repositories."""
from pathlib import Path
import os,platform,re,subprocess,sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
OUT = ROOT / 'build/integration-verification'
OUT.mkdir(parents=True, exist_ok=True)
sources = re.findall(r'"\$\{REPO_ROOT\}/([^"\n]+\.swift)"', (ROOT/'Scripts/run-chavrusa-component-tests.sh').read_text(encoding='utf-8'))
sources = [p for p in sources if p != 'tools/test_chavrusa_text_components.swift']
sources += [
 'Source/Core/Database/SQLiteDatabase.swift', 'Source/Core/Database/ZstdShim.swift',
 'Source/Otzaria/Core/OtzariaSQLiteStatement.swift','Source/Otzaria/Core/OtzariaSQLiteError.swift',
 'Source/Otzaria/Core/String+OtzariaText.swift','Source/Otzaria/Data/OtzariaSchema.swift',
 'Source/Otzaria/Data/OtzariaBookSchemaCompatibility.swift','Source/Otzaria/Data/OtzariaSchemaAwareReadContext.swift',
 'Source/Otzaria/Data/OtzariaTopicsRepository.swift','Source/Otzaria/Data/OtzariaVersionsRepository.swift',
 'Source/Otzaria/Data/OtzariaVersionedContentRepository.swift','Source/Otzaria/Data/OtzariaLineDecorationRepository.swift',
 'Source/Otzaria/Navigation/OtzariaAlternativeTOCRepository.swift','Source/Otzaria/Reading/OtzariaCanonicalLineLocatorResolver.swift',
 'Source/Otzaria/Reading/OtzariaLinkAnchorRepository.swift','Source/Otzaria/Reading/OtzariaSourceToDisplayRangeMap.swift',
 'Source/Otzaria/Search/OtzariaSearchLineIndexResolver.swift',
 'Source/Otzaria/Navigation/OtzariaReferenceResolutionRepository.swift',
 'Source/Otzaria/Data/OtzariaWorkMetadataEnricher.swift',
 'Source/Otzaria/Reading/OtzariaVersionSelectionStore.swift',
 'tools/test_otzaria_schema7.swift',
]
link = []
if platform.system() == 'Windows':
 sources.append('tools/PortableSQLiteLegacyBoundary.swift')
 build = ROOT/'Vendor/OtzariaSearchEngine/ios_bridge/target/debug/build'
 sqlite_libs = list(build.glob('libsqlite3-sys-*/out/sqlite3.lib'))
 zstd_libs = list(build.glob('zstd-sys-*/out/zstd.lib')) + list(build.glob('zstd-sys-*/out/libzstd.lib'))
 headers = list((Path.home()/'.cargo/registry/src').glob('*/libsqlite3-sys-*/sqlite3/sqlite3.h'))
 if not sqlite_libs or not zstd_libs or not headers:
  raise SystemExit('Native SQLite/zstd inputs missing; run the repository cargo check before this portable fixture check.')
 module = OUT/'SQLite3';module.mkdir(exist_ok=True)
 header = max(headers,key=lambda p:p.stat().st_mtime)
 (module/'module.modulemap').write_text('module SQLite3 [system] { header "'+header.as_posix()+'" export * }\n',encoding='utf-8')
 link += ['-I',str(module),'-Xlinker',str(max(sqlite_libs,key=lambda p:p.stat().st_mtime)),
          '-Xlinker',str(max(zstd_libs,key=lambda p:p.stat().st_mtime))]
 binary = OUT/'schema7-tests.exe'
elif platform.system() == 'Darwin':
 sources += ['Source/Core/Database/ZstdDecompressor.swift', 'Source/Core/Database/ZSTDContextWrapper.swift', 'Source/Core/Configuration/AppLogger.swift']
 prefix = subprocess.check_output(['brew','--prefix','zstd'],text=True).strip()
 link += ['-L',prefix+'/lib','-lzstd']
 binary = OUT/'schema7-tests'
else:
 link += ['-lsqlite3','-lzstd']
 binary = OUT/'schema7-tests'
command = ['swiftc','-whole-module-optimization','-parse-as-library',*dict.fromkeys(sources),*link,'-o',str(binary)]
result = subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace')
(OUT/'schema7-compile.log').write_text(result.stdout,encoding='utf-8')
print(result.stdout[-14000:])
if result.returncode: raise SystemExit(result.returncode)
result = subprocess.run([str(binary)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace')
(OUT/'schema7-results.log').write_text(result.stdout,encoding='utf-8')
print(result.stdout[-14000:])
raise SystemExit(result.returncode)
