// Supplemental model of the native single-worker reminder reconciler.
// Exercises a backend whose add commits asynchronously; not an Apple SDK test.
const assert=require('node:assert/strict');
const tick=()=>new Promise(r=>setImmediate(r));
class Backend {
 constructor(){this.pending=new Map();this.waiters=[];this.failure=false;}
 async read(){return [...this.pending.keys()];}
 remove(ids){for(const id of ids)this.pending.delete(id);}
 add(id,value){return new Promise((resolve,reject)=>this.waiters.push(()=>{if(this.failure)reject(Error('failed'));else {this.pending.set(id,value);resolve();}}));}
 commit(){this.waiters.shift()?.();}
}
class Reconciler {
 constructor(backend){this.b=backend;this.desired=new Map();this.revision=0;this.running=false;this.error=null;}
 set(id,value){this.desired.set(id,value);this.changed();}
 cancel(id){this.desired.delete(id);this.b.remove([id]);this.changed();}
 clear(){this.desired.clear();this.changed();}
 changed(){this.revision++;if(!this.running){this.running=true;this.work=this.reconcile();}}
 async reconcile(){while(true){const version=this.revision,snapshot=[...this.desired];const pending=await this.b.read();if(version!==this.revision)continue;this.b.remove(pending);let error=null;for(const [id,value]of snapshot){if(version!==this.revision)break;try{await this.b.add(id,value)}catch{error='reminder failed'}if(version!==this.revision){this.b.remove([id]);break;}}if(version!==this.revision)continue;this.error=error;this.running=false;return;}}
}
(async()=>{
 let b=new Backend(),r=new Reconciler(b);r.set('a','old');await tick();r.cancel('a');b.commit();await r.work;assert.equal(b.pending.size,0);
 b=new Backend();r=new Reconciler(b);r.set('a','old');await tick();r.set('a','new');b.commit();await tick();b.commit();await r.work;assert.equal(b.pending.get('a'),'new');
 b=new Backend();r=new Reconciler(b);r.set('a','a');await tick();r.set('b','b');b.commit();await tick();b.commit();await tick();b.commit();await r.work;assert.deepEqual([...b.pending.keys()].sort(),['a','b']);
 b=new Backend();r=new Reconciler(b);r.set('a','a');await tick();r.clear();b.commit();await r.work;assert.equal(b.pending.size,0);
 b=new Backend();b.failure=true;r=new Reconciler(b);r.set('a','a');await tick();b.commit();await r.work;assert.equal(r.error,'reminder failed');
 console.log('PASS: 5 asynchronous reconciliation scenarios (JS model only).');
})().catch(e=>{console.error(e);process.exit(1)});
