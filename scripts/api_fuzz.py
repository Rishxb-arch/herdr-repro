import socket, json, sys, time, os
P=os.environ["XDG_CONFIG_HOME"]+"/herdr/herdr.sock"
PANE=sys.argv[1] if len(sys.argv)>1 else "w1:p1"
def call(raw, wait=1.0):
    s=socket.socket(socket.AF_UNIX); s.settimeout(wait); s.connect(P)
    s.sendall(raw if isinstance(raw,bytes) else raw.encode())
    out=b""
    try:
        while True:
            d=s.recv(65536)
            if not d: out+=b"<EOF>"; break
            out+=d
            if out.endswith(b"\n"): break
    except socket.timeout: out+=b"<TIMEOUT>"
    s.close(); return out
cases={
 "not json":"hello\n",
 "empty obj":"{}\n",
 "no method":'{"id":"1"}\n',
 "unknown method":'{"id":"1","method":"nope","params":{}}\n',
 "null params":'{"id":"1","method":"pane.get","params":null}\n',
 "wrong type":'{"id":"1","method":"pane.get","params":{"pane_id":5}}\n',
 "id huge int":'{"id":1e999,"method":"ping","params":{}}\n',
 "deep nest":'{"id":"1","method":"ping","params":'+'['*100000+']'*100000+'}\n',
 "bad utf8":b'{"id":"\xff\xfe","method":"ping","params":{}}\n',
 "nul":'{"id":"1\\u0000","method":"ping","params":{}}\n',
 "ping":'{"id":"1","method":"ping","params":{}}\n',
 "send_text huge pane":json.dumps({"id":"1","method":"pane.send_text","params":{"pane_id":PANE,"text":"x"*1000}})+"\n",
 "pane id weird":json.dumps({"id":"1","method":"pane.get","params":{"pane_id":"w1:p99999999999999999999"}})+"\n",
 "pane id neg":json.dumps({"id":"1","method":"pane.get","params":{"pane_id":"w-1:p-1"}})+"\n",
 "pane split bad dir":json.dumps({"id":"1","method":"pane.split","params":{"pane_id":PANE,"direction":"diagonal"}})+"\n",
 "read lines huge":json.dumps({"id":"1","method":"pane.read","params":{"pane_id":PANE,"lines":4294967295}})+"\n",
 "read lines neg":json.dumps({"id":"1","method":"pane.read","params":{"pane_id":PANE,"lines":-1}})+"\n",
}
for k,v in cases.items():
    t=time.time(); r=call(v); print(f"{k:22} {time.time()-t:5.2f}s {r[:200]!r}")
