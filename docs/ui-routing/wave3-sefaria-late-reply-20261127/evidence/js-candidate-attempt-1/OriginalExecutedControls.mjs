// Executes the actual downstream facade and unchanged original RN forwarding
// function with explicit native-module/timer/engine boundary doubles. Not Hermes.
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
const [facadePath, rootPath, resultPath] = process.argv.slice(2);
const facadeSource = fs.readFileSync(facadePath, 'utf8');
const rootSource = fs.readFileSync(rootPath, 'utf8');
const a = rootSource.indexOf('const handleIncomingEnvelope = async');
const z = rootSource.indexOf('export const setupChavrusaRPCBridge', a);
if (a < 0 || z < a) throw new Error('Original RN forwarding source absent');
const rootBody = rootSource.slice(a, z);
const compiled = facadeSource.replace(/^import .*;\r?$/gm, '')
  .replace('export async function loadTextWithProvenance', 'async function loadTextWithProvenance')
  .replace('export class ChavrusaRPCFacade', 'class ChavrusaRPCFacade');
const nonce = '11111111-1111-4111-8111-111111111111';
const requestID = '22222222-2222-4222-8222-222222222222';
const rows = [];
const check = (condition, message) => { if (!condition) throw new Error(message); };
function fixture({eventThrows = false} = {}) {
  const events = [], responses = [], timers = new Map(); let sequence = 0;
  const module = {
    deliverEvent: json => { if (eventThrows) throw new Error('CONTROL_NATIVE_EVENT_FAILED'); events.push(JSON.parse(json)); },
    deliverResponse: json => responses.push(JSON.parse(json)),
  };
  const context = vm.createContext({
    NativeModules: {ChavrusaSefariaBridgeModule: module}, console,
    ChavrusaVisibleSurfaces: {}, AsyncStorage: {}, OfflineOnline: {}, DownloadControl: {},
    loadTextOffline: () => { throw new Error('unrelated engine accessed'); }, textFromRefData: () => {},
    ERRORS: {}, api: {}, Date, JSON, Number, Object, Promise, Error,
    setTimeout: (fn, ms) => { const id = ++sequence; timers.set(id, {fn, ms}); return id; },
    clearTimeout: id => timers.delete(id),
  });
  context.global = context;
  vm.runInContext(compiled + '\n' + rootBody + '\nglobalThis.facade=ChavrusaRPCFacade; globalThis.receive=handleIncomingEnvelope;', context);
  return {context, events, responses, timers, fire() {
    const entries = [...timers]; timers.clear(); for (const [, timer] of entries) timer.fn();
  }};
}
function envelope(options = {}, changes = {}) {
  return {protocolVersion: '1.0', requestID, method: 'diagnostic.echo', backendID: 'sefariaEmbedded',
    sessionGeneration: 7, timeoutMs: 1000, paramsJson: JSON.stringify({
      message: 'שלום', lateReplyDiagnostic: {contract: 'chavrusa.diagnostic.late-reply.v1', nonce, delayMs: 80, ...options},
    }), ...changes};
}
const flush = async () => { for (let i = 0; i < 6; i++) await Promise.resolve(); };
async function test(name, run) {
  try { await run(); rows.push({name, passed: true}); }
  catch (error) { rows.push({name, passed: false, error: String(error)}); }
}
await test('ordinary Hebrew echo preserves original behavior', async () => {
  const f = fixture(); const r = await f.context.facade.handleNativeEnvelope({...envelope(), paramsJson: '{"message":"שלום"}'});
  check(r.status === 'success' && JSON.parse(r.resultJson).echoedMessage === 'שלום', 'original echo changed');
  check(f.events.length === 0 && f.timers.size === 0, 'ordinary echo acquired diagnostic state');
});
await test('original error injection remains exact', async () => {
  const f=fixture(); const r=await f.context.facade.handleNativeEnvelope({...envelope(),paramsJson:'{"injectError":true}'});
  check(r.status==='error' && r.error.code==='ECHO_INJECTED_ERROR','original error assertion changed');
});
await test('actual JS-start receipt precedes delayed completion', async () => {
  const f=fixture(); let settled=false;
  const pending=f.context.facade.handleNativeEnvelope(envelope()).then(r=>{settled=true;return r;});
  await flush(); check(!settled,'response completed before controlled timer');
  check(f.events.length===1 && f.events[0].event==='diagnostic.echo.started','no actual JS start event');
  const p=JSON.parse(f.events[0].payloadJson);
  check(p.requestID===requestID && p.nonce===nonce && p.sessionGeneration===7 && p.delayMs===80,'wrong start binding');
  check(f.timers.size===1 && [...f.timers.values()][0].ms===80,'delay is not bounded exact input');
  f.fire(); const r=await pending; const proof=JSON.parse(r.resultJson).lateReplyDiagnostic;
  check(r.sessionGeneration===7 && proof.requestID===requestID && proof.nonce===nonce && proof.sessionGeneration===7,'old response was retagged');
  check(f.timers.size===0 && f.context.facade.activeEchoDiagnostic===null,'completed diagnostic leaked');
});
await test('unchanged original RN function delivers actual delayed response', async () => {
  const f=fixture();const pending=f.context.receive(JSON.stringify(envelope()));
  await flush(); check(f.events.length===1 && f.responses.length===0,'original forwarding bypassed delay');
  f.fire();const result=JSON.parse(await pending);
  check(f.responses.length===1 && JSON.stringify(f.responses[0])===JSON.stringify(result),'native response differs from actual facade');
  check(result.requestID===requestID && result.sessionGeneration===7,'original forwarding changed identity');
});
for (const [name, option, env] of [
  ['negative delay',{delayMs:-1},{}],['zero delay',{delayMs:0},{}],
  ['fractional delay',{delayMs:1.5},{}],['oversized delay',{delayMs:3001},{}],
  ['missing nonce',{nonce:null},{}],['malformed nonce',{nonce:'unqualified'},{}],
  ['wrong contract',{contract:'other'},{}],['unsafe generation',{}, {sessionGeneration:Number.MAX_SAFE_INTEGER+1}],
  ['zero generation',{}, {sessionGeneration:0}],['foreign backend',{}, {backendID:'otzaria'}],
  ['wrong protocol',{}, {protocolVersion:'2.0'}],['invalid request ID',{}, {requestID:'unqualified'}],
  ['delay reaches timeout',{delayMs:1000},{timeoutMs:1000}],
  ['oversized request deadline',{}, {timeoutMs:10001}],
]) await test(name+' fails before timer or receipt',async()=>{
  const f=fixture();const r=await f.context.facade.handleNativeEnvelope(envelope(option,env));
  check(r.status==='error','invalid diagnostic accepted');
  check(f.events.length===0 && f.timers.size===0,'invalid diagnostic allocated work');
});
await test('original injected error cannot mix with delayed proof',async()=>{
  const f=fixture();const e=envelope();const p=JSON.parse(e.paramsJson);p.injectError=true;e.paramsJson=JSON.stringify(p);
  const r=await f.context.facade.handleNativeEnvelope(e);
  check(r.status==='error' && r.error.message==='DIAGNOSTIC_DELAY_CONFLICT','conflicting diagnostic not refused');
  check(f.events.length===0 && f.timers.size===0,'conflict allocated hold');
});
await test('second held echo cannot replace first original identity',async()=>{
  const f=fixture();const first=f.context.facade.handleNativeEnvelope(envelope());await flush();
  const second=await f.context.facade.handleNativeEnvelope(envelope({nonce:'33333333-3333-4333-8333-333333333333'},{requestID:'44444444-4444-4444-8444-444444444444'}));
  check(second.status==='error' && second.error.message==='DIAGNOSTIC_DELAY_BUSY','second echo replaced pending identity');
  check(f.events.length===1 && f.timers.size===1,'second echo changed first evidence');
  f.fire();const r=await first;check(JSON.parse(r.resultJson).lateReplyDiagnostic.nonce===nonce,'first proof was transferred');
});
await test('native event failure releases exact timer and record',async()=>{
  const f=fixture({eventThrows:true});const r=await f.context.facade.handleNativeEnvelope(envelope());
  check(r.status==='error' && r.error.message==='CONTROL_NATIVE_EVENT_FAILED','native event error swallowed');
  check(f.timers.size===0 && f.context.facade.activeEchoDiagnostic===null,'failed start leaked state');
});
await test('ordinary echo remains independent during held diagnostic',async()=>{
  const f=fixture();const pending=f.context.facade.handleNativeEnvelope(envelope());await flush();
  const fresh=await f.context.facade.handleNativeEnvelope({...envelope(),requestID:'55555555-5555-4555-8555-555555555555',sessionGeneration:8,paramsJson:'{"message":"fresh"}'});
  check(fresh.status==='success' && fresh.sessionGeneration===8 && JSON.parse(fresh.resultJson).echoedMessage==='fresh','new generation echo blocked or retagged');
  f.fire();const old=await pending;check(old.sessionGeneration===7,'old echo borrowed new epoch');
});
const result={boundary:'actual original JS facade and extracted unchanged original RN forwarding; explicit native/timer/engine doubles; no Hermes/app acceptance',
  inputs:[facadePath,rootPath].map(path=>({path,sha256:crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex')})),
  originalRootBodySHA256:crypto.createHash('sha256').update(rootBody).digest('hex'),
  caseCount:rows.length,passed:rows.filter(x=>x.passed).length,failed:rows.filter(x=>!x.passed).length,cases:rows};
fs.writeFileSync(resultPath,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));process.exitCode=result.failed?1:0;
