// SecureEncrypt right-click helper (runs under wscript, so it opens no console window).
// Explorer starts one process per selected item. Instead of guessing how long the others take,
// the first thing each instance does is ask Explorer which items are selected in the window the
// clicked item is in. All instances of one selection compute the same key; the first one takes
// the lock and starts ONE visible SecureEncrypt window with the whole selection, the others quit.
// Without a usable Explorer selection (desktop, search results, ...) the older queue method is used:
// the instances queue their paths, the leader waits until nothing new arrives, and the window merges
// stragglers via /late while the user types the password.
var sh = new ActiveXObject("WScript.Shell");
var fso = new ActiveXObject("Scripting.FileSystemObject");

if (WScript.Arguments.length < 1) { WScript.Quit(1); }

var QUIET = 1500;          // ms without a new item before the first window is started (queue method)
var MAXWAIT = 15000;       // ms, upper limit for the quiet wait (queue method)
var LINGER = 90000;        // ms the helper waits for the window to take over before it cleans up (queue method)
var STALE = 120000;        // ms after which a lock file left behind is ignored
var SELLOCK = 20000;       // ms the selection lock is held, so late instances of the same selection quit
try {
    var ev = sh.Environment("Process")("SE_SHIM_LINGER_MS");
    if (ev && ev.length > 0) { LINGER = parseInt(ev, 10); }
    var ev2 = sh.Environment("Process")("SE_SHIM_SELLOCK_MS");
    if (ev2 && ev2.length > 0) { SELLOCK = parseInt(ev2, 10); }
} catch (e0) { }

var target = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "SecureEncrypt.cmd");
var q = fso.BuildPath(sh.ExpandEnvironmentStrings("%TEMP%"), "SecureEncrypt_queue");
if (!fso.FolderExists(q)) { try { fso.CreateFolder(q); } catch (e1) { } }

function norm(p) {
    var s = String(p).toLowerCase();
    while (s.length > 3 && s.charAt(s.length - 1) == "\\") { s = s.substring(0, s.length - 1); }
    return s;
}

// One visible window with all paths; late = look for stragglers.
// The paths travel in a small Unicode list file (/list), not on the command line: cmd.exe would expand a
// %VARIABLE% pattern inside a file name. The outer quotes of the cmd /c line are stripped by cmd.
function launch(list, late) {
    list.sort();
    var listFile = fso.BuildPath(q, "list_" + new Date().getTime() + "_" + Math.floor(Math.random() * 1000000) + ".txt");
    var lf = fso.CreateTextFile(listFile, true, true);
    lf.Write(list.join("\r\n"));
    lf.Close();
    var inner = '"' + target + '"' + (late ? " /late" : "") + ' /list "' + listFile + '"';
    sh.Run('cmd.exe /c "' + inner + '"', 1, false);
}

// ---------------------------------------------------------------- selection method

// Paths of the selection of the Explorer window that contains 'clicked', or null.
function getSelection(clicked) {
    try {
        var shell = new ActiveXObject("Shell.Application");
        var wins = shell.Windows();
        var want = norm(clicked);
        for (var i = 0; i < wins.Count; i++) {
            var w = null;
            try { w = wins.Item(i); } catch (e2) { continue; }
            if (w == null) { continue; }
            var items = null;
            try { items = w.Document.SelectedItems(); } catch (e3) { continue; }
            if (items == null || items.Count < 1) { continue; }
            var paths = [];
            var found = false;
            for (var k = 0; k < items.Count; k++) {
                var pth = "";
                try { pth = items.Item(k).Path; } catch (e4) { }
                if (pth && pth.length > 0) {
                    paths.push(pth);
                    if (norm(pth) == want) { found = true; }
                }
            }
            if (found) { return paths; }
        }
    } catch (e5) { }
    return null;
}

function selectionKey(paths) {
    var a = [];
    for (var i = 0; i < paths.length; i++) { a.push(norm(paths[i])); }
    a.sort();
    var s = a.join("|");
    var h = 5381;
    for (var j = 0; j < s.length; j++) { h = ((h * 33) ^ s.charCodeAt(j)) & 0x7fffffff; }
    return h.toString(16) + "_" + a.length;
}

function cleanSelectionLocks() {
    try {
        var en = new Enumerator(fso.GetFolder(q).Files);
        for (; !en.atEnd(); en.moveNext()) {
            var file = en.item();
            if (!/^sel_.*\.lock$/i.test(file.Name)) { continue; }
            var old = true;
            try {
                var r = fso.OpenTextFile(file.Path, 1, false);
                var stamp = parseInt(r.ReadAll(), 10);
                r.Close();
                if (!isNaN(stamp) && (new Date().getTime() - stamp) < STALE) { old = false; }
            } catch (e6) { }
            if (old) { try { fso.DeleteFile(file.Path, true); } catch (e7) { } }
        }
    } catch (e8) { }
}

function runWithSelection(sel) {
    cleanSelectionLocks();
    var lockPath = fso.BuildPath(q, "sel_" + selectionKey(sel) + ".lock");
    try {
        var l = fso.CreateTextFile(lockPath, false);
        l.Write(String(new Date().getTime()));
        l.Close();
    } catch (e9) { return; }          // another instance of this very selection already started the window
    launch(sel, false);
    WScript.Sleep(SELLOCK);           // keep the lock so the remaining instances of this selection quit
    try { fso.DeleteFile(lockPath, true); } catch (e10) { }
}

var selection = getSelection(WScript.Arguments(0));
if (selection != null && selection.length > 0) {
    runWithSelection(selection);
    WScript.Quit(0);
}

// ---------------------------------------------------------------- queue method (fallback)

// 1) queue my path (write to .tmp, rename when complete so the leader never reads a half written file)
var id = new Date().getTime() + "_" + Math.floor(Math.random() * 1000000);
var tmp = fso.BuildPath(q, id + ".tmp");
var f = fso.CreateTextFile(tmp, true, true);
f.Write(WScript.Arguments(0));
f.Close();
fso.MoveFile(tmp, fso.BuildPath(q, id + ".txt"));

// 2) leader election: only one instance can create the lock file.
//    The lock holds its own creation time, so no file date conversion is needed to detect a stale lock.
var lock = fso.BuildPath(q, "leader.lock");
var leader = false;
for (var attempt = 0; attempt < 2 && !leader; attempt++) {
    try {
        var l2 = fso.CreateTextFile(lock, false);
        l2.Write(String(new Date().getTime()));
        l2.Close();
        leader = true;
    } catch (e11) {
        var stale = false;
        try {
            var r2 = fso.OpenTextFile(lock, 1, false);
            var stamp2 = parseInt(r2.ReadAll(), 10);
            r2.Close();
            if (!isNaN(stamp2) && (new Date().getTime() - stamp2) > STALE) { stale = true; }
        } catch (e12) { }
        if (stale) { try { fso.DeleteFile(lock, true); } catch (e13) { } } else { break; }
    }
}
if (!leader) { WScript.Quit(0); }

function queued() {
    var n = 0;
    var en = new Enumerator(fso.GetFolder(q).Files);
    for (; !en.atEnd(); en.moveNext()) { if (/\.txt$/i.test(en.item().Name)) { n++; } }
    return n;
}

// moves all queued paths into 'list' (and removes them from the queue)
function collect(list) {
    var en = new Enumerator(fso.GetFolder(q).Files);
    for (; !en.atEnd(); en.moveNext()) {
        var file = en.item();
        if (!/\.txt$/i.test(file.Name)) { continue; }
        var p = "";
        try {
            var t = fso.OpenTextFile(file.Path, 1, false, -1);
            p = t.ReadAll();
            t.Close();
            fso.DeleteFile(file.Path, true);
        } catch (e14) { continue; }
        var dup = false;
        for (var i = 0; i < list.length; i++) { if (list[i].toLowerCase() == p.toLowerCase()) { dup = true; } }
        if (p.length > 0 && !dup) { list.push(p); }
    }
}

// 3) wait until no new item has arrived for QUIET ms (slow machines start the instances late)
var lastCount = queued();
var quiet = 0;
var waited = 0;
while (quiet < QUIET && waited < MAXWAIT) {
    WScript.Sleep(250);
    waited += 250;
    var now = queued();
    if (now != lastCount) { lastCount = now; quiet = 0; } else { quiet += 250; }
}
var first = [];
collect(first);
if (first.length > 0) { launch(first, true); }

// 4) the window removes the lock when it has merged the stragglers; wait for that
var t0 = new Date().getTime();
while (fso.FileExists(lock) && (new Date().getTime() - t0) < LINGER) { WScript.Sleep(250); }
if (fso.FileExists(lock)) {
    // the window did not take over in time: release the lock and give the leftovers a window of their own
    var rest = [];
    collect(rest);
    try { fso.DeleteFile(lock, true); } catch (e15) { }
    collect(rest);
    if (rest.length > 0) { launch(rest, true); }
}
