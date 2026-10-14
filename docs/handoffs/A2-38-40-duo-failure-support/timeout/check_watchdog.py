from pathlib import Path
import os, subprocess, sys, tempfile, time
root=Path(__file__).resolve().parent
helper=root/'run-with-deadline.py'
def run(code, wall=1, idle=.3):
    t=time.monotonic()
    p=subprocess.run([sys.executable,str(helper),'--seconds',str(wall),'--idle-seconds',str(idle),'--grace-seconds','.1','--',sys.executable,'-u','-c',code],capture_output=True,text=True,timeout=4)
    return p,time.monotonic()-t
p,t=run("print('ok')")
assert p.returncode==0 and p.stdout=='ok\n'
p,t=run("import sys;print('bad');sys.exit(7)")
assert p.returncode==7 and 'bad' in p.stdout
p,t=run("import time; print('before hang');time.sleep(30)")
assert p.returncode==124 and 'no-output deadline' in p.stdout and t<2
p,t=run("import time\nwhile True: print('alive');time.sleep(.05)",wall=.4,idle=.2)
assert p.returncode==124 and 'wall-clock deadline' in p.stdout and t<2
# Child ignores TERM and tries to write later: group KILL must stop it,
# even when the parent exits on TERM.
with tempfile.TemporaryDirectory() as d:
    marker=str(Path(d)/'escaped')
    child="import signal,time,pathlib;signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(1);pathlib.Path(%r).write_text('bad');time.sleep(30)"%marker
    code="import subprocess,sys,time;subprocess.Popen([sys.executable,'-u','-c',%r]);print('child started');time.sleep(30)"%child
    p,t=run(code)
    assert p.returncode==124
    time.sleep(1.1)
    assert not Path(marker).exists()
# Leader exits but child retains its stdout pipe: still deadline-bounded.
p,t=run("import subprocess,sys;subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])")
assert p.returncode==124 and t<2
print('6 watchdog checks passed: success, failure, idle, busy wall-clock, TERM-resistant descendant, inherited pipe.')
