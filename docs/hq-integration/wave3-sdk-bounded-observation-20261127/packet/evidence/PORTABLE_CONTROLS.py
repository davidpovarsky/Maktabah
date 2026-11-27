"""Focused portable refusal controls for the process-observation replacement.

All OS/process responses are explicit boundaries. These checks do not observe a
Mac, acquire a compiler slot, or establish SDK/native acceptance.
"""
from pathlib import Path
import importlib.util,json,subprocess,sys,unittest
from unittest.mock import patch

BASE=Path(__file__).parent/'launch-envelope-bounded'
sys.path.insert(0,str(BASE))
import sdk_process_observation as observer
def module(name):
 spec=importlib.util.spec_from_file_location(name,BASE/(name+'.py'))
 result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
launcher=module('launch_owned')

class Controls(unittest.TestCase):
 def result(self,stdout='  PID  PPID COMMAND\n 101 1 /usr/bin/python3 ordinary.py\n',stderr=''):
  return subprocess.CompletedProcess(['/bin/ps'],0,stdout,stderr)
 def test_low_capacity_precedes_any_identity_git_or_process_read(self):
  with patch.object(observer,'free_bytes',return_value=15032385535),patch.object(launcher,'git',side_effect=AssertionError('source read too early')),patch.object(launcher,'identity',side_effect=AssertionError('identity read too early')),patch.object(launcher,'require_original_sdk_slot',side_effect=AssertionError('process read too early')),patch.object(sys,'argv',['launch_owned.py','--execute-root-authorized-attempt']):
   with self.assertRaisesRegex(RuntimeError,'fourteen-GiB'):launcher.main()
 def test_admission_exact_boundary_is_unchanged(self):
  with patch.object(observer,'free_bytes',return_value=15032385536):self.assertEqual(observer.require_launch_capacity(),15032385536)
 def test_clean_argument_inventory_retains_timeout_and_exact_predicate(self):
  with patch.object(observer.subprocess,'run',return_value=self.result())as run:
   result=observer.require_original_sdk_slot('/reviewed/sdk')
  self.assertEqual(result['processCount'],1);self.assertEqual(run.call_args.kwargs['timeout'],5)
  self.assertEqual(run.call_args.args[0],['/bin/ps','-axo','pid,ppid,command'])
 def test_queued_python_runner_blocks_even_without_compiler_name(self):
  output='PID PPID COMMAND\n101 1 /python /reviewed/sdk/Tools/prepare_local_execution.py\n'
  with patch.object(observer.subprocess,'run',return_value=self.result(output)):
   with self.assertRaisesRegex(RuntimeError,'SDK slot already active'):observer.require_original_sdk_slot('/reviewed/sdk')
 def test_unrelated_root_does_not_match_original_predicate(self):
  output='PID PPID COMMAND\n101 1 /python /other/sdk/Tools/prepare_local_execution.py\n'
  with patch.object(observer.subprocess,'run',return_value=self.result(output)):
   self.assertEqual(observer.require_original_sdk_slot('/reviewed/sdk')['processCount'],1)
 def test_timeout_cannot_be_empty_success(self):
  with patch.object(observer.subprocess,'run',side_effect=subprocess.TimeoutExpired(['/bin/ps'],5)):
   with self.assertRaises(subprocess.TimeoutExpired):observer.require_original_sdk_slot('/reviewed/sdk')
 def test_process_read_failure_cannot_be_empty_success(self):
  with patch.object(observer.subprocess,'run',side_effect=subprocess.CalledProcessError(1,['/bin/ps'])):
   with self.assertRaises(subprocess.CalledProcessError):observer.require_original_sdk_slot('/reviewed/sdk')
 def test_partial_or_malformed_inventory_refuses(self):
  for output in ['', 'PID PPID COMMAND\n', 'PID COMMAND\n1 hello\n','PID PPID COMMAND\nxx 1 test\n']:
   with self.subTest(output=output),patch.object(observer.subprocess,'run',return_value=self.result(output)):
    with self.assertRaises(RuntimeError):observer.require_original_sdk_slot('/reviewed/sdk')
 def test_diagnostic_stderr_refuses(self):
  with patch.object(observer.subprocess,'run',return_value=self.result(stderr='could not read process')):
   with self.assertRaisesRegex(RuntimeError,'Incomplete'):observer.require_original_sdk_slot('/reviewed/sdk')
 def test_live_compiler_metadata_refuses_without_signaling(self):
  for executable in sorted(observer.COMPILER_NAMES):
   with self.subTest(executable=executable),patch.object(observer,'bsd_snapshot',return_value={123:{'pid':123,'executable':executable}}),patch.object(observer.os,'kill',side_effect=AssertionError('foreign signal')):
    with self.assertRaisesRegex(RuntimeError,'compiler slot occupied'):observer.require_compiler_slot()
 def test_bsd_read_failure_refuses(self):
  with patch.object(observer,'bsd_snapshot',side_effect=RuntimeError('unreadable BSD inventory')):
   with self.assertRaisesRegex(RuntimeError,'unreadable'):observer.require_compiler_slot()
 def test_owned_identity_preserves_precise_start_and_group(self):
  row={'pid':123,'ppid':122,'pgid':123,'uid':observer.os.geteuid(),'started':'1795812000.123456','executable':'Python','sid':123,'state':'S'}
  with patch.object(observer,'bsd_snapshot',return_value={123:row}):value=observer.identity(123)
  self.assertTrue(value['available']);self.assertEqual(value['start'],row['started']);self.assertEqual(value['pgid'],123)
 def test_absent_owned_process_is_unavailable_not_other_identity(self):
  with patch.object(observer,'bsd_snapshot',return_value={}):self.assertFalse(observer.identity(123)['available'])
 def test_foreign_uid_refuses_owned_identity(self):
  row={'pid':123,'uid':observer.os.geteuid()+1}
  with patch.object(observer,'bsd_snapshot',return_value={123:row}):
   with self.assertRaisesRegex(RuntimeError,'identity changed'):observer.identity(123)

if __name__=='__main__':
 suite=unittest.defaultTestLoader.loadTestsFromTestCase(Controls)
 result=unittest.TextTestRunner(verbosity=2).run(suite)
 output={'status':'PASS_PORTABLE_OBSERVER_BOUNDARIES'if result.wasSuccessful()else'FAIL','methodsRun':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'realMacObservations':0,'SDKBuilds':0,'scope':__doc__}
 (BASE/'PORTABLE_OBSERVER_CONTROLS.json').write_text(json.dumps(output,indent=2)+'\n')
 raise SystemExit(0 if result.wasSuccessful()else 1)
