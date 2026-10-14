// Usage: node test/browser_navigation_smoke.mjs <fixture-build> <browser-exe>
// Uses an isolated browser profile and synthetic data; never connects to the API.
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import os from 'node:os';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';

const root = path.resolve(process.argv[2]);
const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'secretpod-navigation-'));
const mime = {'.html':'text/html', '.js':'text/javascript', '.json':'application/json', '.wasm':'application/wasm'};
const server = http.createServer(async (req,res) => {
  const name = new URL(req.url,'http://localhost').pathname;
  const file = path.resolve(root, '.' + (name === '/' ? '/index.html' : name));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  try { res.writeHead(200, {'Content-Type':mime[path.extname(file)] ?? 'application/octet-stream'}); res.end(await fs.readFile(file)); }
  catch { res.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
const url = `http://127.0.0.1:${server.address().port}/`;
const browser = spawn(process.argv[3], ['--headless=new','--no-first-run','--no-default-browser-check',
  '--disable-sync','--disable-features=msEdgeFirstRunExperience','--remote-debugging-port=0',
  `--user-data-dir=${profile}`, 'about:blank'], {windowsHide:true,stdio:'ignore'});
const delay = ms => new Promise(resolve => setTimeout(resolve,ms));
let socket;
try {
  let port;
  for (let i=0;i<150;i++) {
    try { port=(await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]; break; } catch { await delay(100); }
  }
  if (!port) throw new Error('Browser did not start');
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket = new WebSocket(targets.find(t=>t.type==='page' && t.url==='about:blank').webSocketDebuggerUrl);
  await new Promise(resolve=>socket.addEventListener('open',resolve,{once:true}));
  let id=0;
  const pending=new Map();
  socket.addEventListener('message', e=>{
    const message=JSON.parse(e.data);
    if(message.id && pending.has(message.id)) {
      const {resolve,reject}=pending.get(message.id); pending.delete(message.id);
      if(message.error) reject(new Error(JSON.stringify(message.error))); else resolve(message.result);
    }
  });
  function cdp(method,params={}) {
    return new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});socket.send(JSON.stringify({id:n,method,params}));});
  }
  async function evaluate(expression) {
    const result=await cdp('Runtime.evaluate',{expression,returnByValue:true});
    if(result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
    return result.result.value;
  }
  const action = name => evaluate(`window.navigationFixture(${JSON.stringify(name)})`);
  const state = () => evaluate('JSON.stringify({ui:JSON.parse(window.navigationFixture("state")),hash:location.hash,depth:history.state?.state?.overlayDepth,index:history.state?.state?.historyIndex,length:history.length})').then(JSON.parse);
  async function until(predicate,label) {
    let last;
    for(let i=0;i<150;i++) { try { last=await state(); if(predicate(last)) return last; } catch {} await delay(100); }
    throw new Error(`${label}: ${JSON.stringify(last)}`);
  }
  async function navigate(page,hash) { await action(String(page)); await until(s=>s.ui.page===page && s.hash===hash,hash); }
  async function discard() {
    await action('close'); await until(s=>s.ui.confirmation && s.depth===2,'confirmation');
    await action('Discard changes'); await until(s=>!s.ui.editor && s.depth===0,'discard');
  }
  await cdp('Page.enable');
  await cdp('Page.navigate',{url:url+'#/secrets'});
  const initial=await until(s=>s.ui.page===0 && s.depth===0,'initial page');
  await action('edit'); await until(s=>s.ui.editor && s.depth===1 && s.length===initial.length+1,'first-entry editor history');
  await action('draft'); await evaluate('history.back()');
  await until(s=>s.ui.confirmation && s.depth===2,'first-entry Back guard');
  await action('Keep editing'); await until(s=>s.ui.editor && !s.ui.confirmation && s.depth===1,'keep editing');
  assert.equal((await state()).ui.draft,'Unsaved fixture');
  await discard();
  const discarded = await state();
  await evaluate('history.forward()');
  await until(s=>s.index===discarded.index+1 && !s.ui.editor && s.depth===0,'Forward cannot recreate a discarded editor');
  await evaluate('history.back()');
  await until(s=>s.index===discarded.index && !s.ui.editor && s.depth===0,'return from stale dialog entry');
  console.log('PASS: Back on first app entry protects the unsaved draft');

  await navigate(1,'#/activity'); await navigate(0,'#/secrets');
  await action('edit'); await until(s=>s.depth===1,'editor'); await action('draft');
  await evaluate('history.back()'); await until(s=>s.ui.confirmation && s.depth===2,'Back confirmation');
  await action('Keep editing'); await until(s=>!s.ui.confirmation && s.depth===1,'keep editing');
  await discard(); await evaluate('history.back()');
  await until(s=>s.ui.page===1 && s.hash==='#/activity','preserved Activity history');
  await evaluate('history.forward()'); await until(s=>s.ui.page===0 && s.hash==='#/secrets','Forward');
  console.log('PASS: dialog dismissal preserves previous page and Forward');

  await navigate(2,'#/members'); await navigate(3,'#/invitations'); await navigate(4,'#/settings');
  await evaluate('history.back()'); await until(s=>s.ui.page===3,'account Back');
  await evaluate('history.forward()'); await until(s=>s.ui.page===4,'account Forward');
  const loaded = new Promise((resolve,reject) => {
    const timeout=setTimeout(()=>reject(new Error('Reload timed out')),15000);
    const listener=e=>{
      if(JSON.parse(e.data).method==='Page.loadEventFired') {
        clearTimeout(timeout); socket.removeEventListener('message',listener); resolve();
      }
    };
    socket.addEventListener('message',listener);
  });
  await cdp('Page.reload'); await loaded;
  await until(s=>s.ui.page===4 && s.hash==='#/settings','refresh direct link');
  console.log('PASS: workspace/account Back, Forward, and refresh');
} finally {
  socket?.close(); browser.kill(); server.close();
}
