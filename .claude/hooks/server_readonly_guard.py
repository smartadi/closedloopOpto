#!/usr/bin/env python3
"""
server_readonly_guard.py -- Claude Code PreToolUse hook (v1, 2026-10-11).

Claude may READ the lab file servers but must never write, move, rename or delete
anything on them (user, 2026-10-11: "you do not have permission to edit files on
server ... make sure we make a hook that makes sure of this").

Blocks (exit 2; the reason goes to stderr, which Claude sees):
  * Write / Edit / MultiEdit / NotebookEdit whose target is on a server;
  * Bash / PowerShell commands that write to a server: redirects into it, rm / mv /
    mkdir / touch / Remove-Item / Set-Content ..., copies whose DESTINATION is on it,
    sed -i, git writes, cd-into-server followed by a write, $VAR indirection,
    pipelines that start on the server and end in a write, and any unrecognised
    command that names a server path;
  * Python / MATLAB code (inline, a local script named on the command line, MATLAB MCP
    code, and the repo scripts that MATLAB code calls by name) that calls a write
    function on a server path or on a variable built from one (expPath, serverRoot...).
Reading stays allowed: ls, cat, grep, np.load, loadUVt, copying server -> local.

Heuristic, not a sandbox: it cannot see paths built at run time inside functions it
never reads (it scans called scripts one level deep). It errs toward blocking.
Self-test: a Bash/PowerShell command containing the SELFTEST marker below is blocked.
"""
import json, os, re, sys, time

# ---------------------------------------------------------------- server paths
_HOSTS = r'(?:sahale|steinmetzsuper1|zserver|tower)(?:\.[\w-]+)*'
_DOMAINS = r'[\w-]+(?:\.[\w-]+)*\.(?:washington\.edu|cortexlab\.net|wanprc\.org)'
SERVER = re.compile(
    r'(?:\\\\|(?<![:\w/])//|UNC\\)(?:' + _HOSTS + '|' + _DOMAINS + r')(?![\w.-])'   # UNC \\host or //host
    r'|(?<![\w$])[zZ]:[\\/]'                    # Z: = \\tower.wanprc.org\Azadeh (net use)
    r'|(?:^|(?<=[\s\'"=(,;]))/[zZ]/',           # Git Bash view of Z:
    re.I | re.M)
SEED_CALLS = re.compile(r'\b(?:dat\.)?(?:expPath|reposPath)\s*\(', re.I)   # MATLAB server-path builders
SELFTEST = '__SERVER_GUARD_SELFTEST__'


class Blocked(Exception):
    pass


def block(reason):
    raise Blocked(reason)


# ---------------------------------------------------------------- small helpers
def strip_q(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in '"\'':
        return s[1:-1]
    return s


def split_top(s, seps=(',',)):
    """Split on separators at bracket depth 0 and outside quotes."""
    out, cur, depth, q = [], '', 0, None
    for ch in s:
        if q:
            cur += ch
            if ch == q:
                q = None
            continue
        if ch in '"\'':
            q = ch
        elif ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
            if depth < 0:
                break
        if depth == 0 and ch in seps:
            out.append(cur)
            cur = ''
            continue
        cur += ch
    out.append(cur)
    return out


def call_args(code, open_paren_idx):
    """Text inside the call's parentheses starting at code[open_paren_idx] == '('."""
    depth, q, i = 0, None, open_paren_idx
    while i < len(code):
        ch = code[i]
        if q:
            if ch == q:
                q = None
        elif ch in '"\'':
            # MATLAB transpose (a') is not a quote; good enough to treat after word chars as transpose
            if ch == "'" and i > 0 and (code[i - 1].isalnum() or code[i - 1] in ')]}_.'):
                pass
            else:
                q = ch
        elif ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return code[open_paren_idx + 1:i]
        elif ch == '\n' and depth <= 1 and q is None and code[open_paren_idx:i].count('...') == 0 \
                and not code[open_paren_idx:i].rstrip().endswith(('\\', ',')):
            pass
        i += 1
    return code[open_paren_idx + 1:]


# ---------------------------------------------------------------- code (MATLAB / Python)
M_WRITE = (r'save|savefig|saveas|exportgraphics|exportapp|print|imwrite|writeNPY|writetable|writematrix|'
           r'writecell|writestruct|writelines|dlmwrite|csvwrite|xlswrite|audiowrite|h5create|h5write|'
           r'h5writeatt|ncwrite|nccreate|mkdir|rmdir|delete|movefile|fileattrib|zip|gzip|gunzip|tar|'
           r'VideoWriter|matfile|diary|paperExport|jnExport|exportPaperFig')
M_DEST = {'copyfile': 1, 'unzip': 1, 'untar': 1}          # only the destination argument matters
M_FIRSTARG = {'save', 'diary'}                              # path is the first argument
P_WRITE = (r'np\.save|np\.savez|np\.savez_compressed|np\.savetxt|numpy\.save\w*|\.tofile|\.to_csv|'
           r'\.to_parquet|\.to_pickle|\.to_excel|\.to_hdf|\.to_json|\.to_feather|\.to_netcdf|\.to_zarr|'
           r'savemat|scipy\.io\.savemat|\.savefig|imsave|imwrite|json\.dump|pickle\.dump|joblib\.dump|'
           r'torch\.save|os\.(?:remove|unlink|rename|replace|makedirs|mkdir|rmdir|removedirs|chmod|utime|'
           r'symlink|link|truncate)|shutil\.(?:move|rmtree|make_archive)|\.write_text|\.write_bytes|'
           r'\.mkdir|\.touch|\.unlink|\.rmdir|\.rename|\.symlink_to|\.hardlink_to|\.chmod')
P_DEST = {'shutil.copy': 1, 'shutil.copy2': 1, 'shutil.copyfile': 1, 'shutil.copytree': 1,
          'shutil.unpack_archive': 1}
PATH_BUILDERS = {'fullfile', 'fileparts', 'strcat', 'sprintf', 'horzcat', 'strrep', 'char', 'string',
                 'cat', 'join', 'strjoin', 'regexprep', 'genpath', 'expPath', 'dat.expPath', 'reposPath',
                 'dat.reposPath', 'os.path.join', 'os.path.dirname', 'os.path.abspath', 'os.path.normpath',
                 'os.path.realpath', 'Path', 'pathlib.Path', 'PurePath', 'PureWindowsPath', 'WindowsPath',
                 'str', 'os.fspath', 'f', 'format'}


def statements(code):
    """-> [(pos, stmt)] split on newlines and top-level ';' (and ',' for MATLAB command syntax)."""
    out, off = [], 0
    for line in code.splitlines(True):
        p = off
        for stmt in split_top(line, seps=(';',)):
            out.append((p, stmt))
            p += len(stmt) + 1
        off += len(line)
    return out


class Taint:
    """Flow-sensitive: a name is a server path from the assignment that makes it one until the
    next assignment that does not. Data loaded FROM the server (x = np.load(server), d =
    loadData(serverRoot)) is not a path, so only path-building expressions propagate."""

    def __init__(self, code):
        self.hist = {}
        cur = set()
        for pos, stmt in statements(code):
            m = re.match(r'\s*([A-Za-z_]\w*(?:\.\w+)*)\s*=(?!=)\s*(.+?)\s*$', stmt)
            if not m:
                continue
            name, expr = m.group(1), m.group(2)
            ref = bool(SERVER.search(expr) or SEED_CALLS.search(expr)) or \
                any(re.search(r'(?<![\w.])' + re.escape(n) + r'\b', expr) for n in cur)
            lead = re.match(r'\s*([A-Za-z_][\w.]*)\s*\(', expr)
            pathy = (lead is None) or (lead.group(1) in PATH_BUILDERS) or lead.group(1).endswith('.join') \
                or bool(SEED_CALLS.match(expr.strip()))
            hit = ref and pathy
            self.hist.setdefault(name, []).append((pos, hit))
            (cur.add if hit else cur.discard)(name)

    def at(self, p):
        names = set()
        for n, h in self.hist.items():
            last = [hit for pos, hit in h if pos <= p]
            if last and last[-1]:
                names.add(n)
        return names


def is_srv_text(text, names):
    return bool(SERVER.search(text) or SEED_CALLS.search(text)) or any(
        re.search(r'(?<![\w.\'"])' + re.escape(n) + r'\b', text) for n in names)


def code_check(code, lang, ctx, depth=0):
    """lang: 'm' (MATLAB) or 'py'. ctx: dict(cwd_srv=bool, roots=[dirs]). Position-aware."""
    T = Taint(code)
    cds = [(-1, ctx.get('cwd_srv', False))]           # (pos, into_server) events, in order
    if lang == 'm':
        for m in re.finditer(r'\bcd\s*\(([^)]*)\)', code):
            cds.append((m.start(), is_srv_text(m.group(1), T.at(m.start()))))
        for pos, st in statements(code):
            for sub in split_top(st, seps=(',',)):
                m = re.match(r'\s*cd\s+([^\s(=][^\s;,%]*)', sub)
                if m:
                    cds.append((pos, is_srv_text(m.group(1), T.at(pos))))
    else:
        for m in re.finditer(r'\bos\.chdir\s*\(([^)]*)\)', code):
            cds.append((m.start(), is_srv_text(m.group(1), T.at(m.start()))))
    cds.sort()
    writes = []   # (pos, name, argtext)
    if lang == 'm':
        for m in re.finditer(r'\b(' + M_WRITE + r'|copyfile|unzip|untar|fopen|system|dos|unix)\s*\(', code):
            fn = m.group(1)
            args = call_args(code, m.end() - 1)
            parts = split_top(args)
            if fn == 'fopen':
                mode = strip_q(parts[1]) if len(parts) > 1 else 'r'
                if not re.search(r'[waWA+]', mode):
                    continue
            if fn in ('system', 'dos', 'unix'):
                lits = [a or b for a, b in re.findall(r"'([^']*)'|\"([^\"]*)\"", args)]
                if lits:
                    shell_check(' '.join(lits), dict(ctx, cwd_srv=cd_at(cds, m.start())), depth + 1)
                continue
            if fn in M_DEST:
                k = M_DEST[fn]
                writes.append((m.start(), fn, parts[k] if len(parts) > k else ''))
            elif fn in M_FIRSTARG:
                writes.append((m.start(), fn, parts[0]))
            else:
                writes.append((m.start(), fn, args))
        for pos, st in statements(code):          # command syntax: "save x.mat a", "mkdir \srv\x"
            for sub in split_top(st, seps=(',',)):
                m = re.match(r'\s*(save|mkdir|rmdir|delete|movefile|copyfile|print|diary)\s+([^=(\s][^\n;%]*)', sub)
                if m:
                    a = m.group(2).split()
                    arg = (a[0] if m.group(1) in M_FIRSTARG else (a[1] if m.group(1) == 'copyfile' and len(a) > 1 else m.group(2))) if a else ''
                    writes.append((pos, m.group(1), arg))
        for m in re.finditer(r'^\s*!(.+)$', code, re.M):
            shell_check(m.group(1), dict(ctx, cwd_srv=cd_at(cds, m.start())), depth + 1)
    else:
        for m in re.finditer(r'(?<![\w.])(?:io\.)?open\s*\(', code):
            args = call_args(code, m.end() - 1)
            parts = split_top(args)
            mm = re.search(r'\bmode\s*=\s*[rbf]*[\'"]([^\'"]+)', args)
            mode = mm.group(1) if mm else (strip_q(parts[1]) if len(parts) > 1 and re.match(r'\s*[\'"]', parts[1]) else 'r')
            if re.search(r'[wax+]', mode):
                writes.append((m.start(), 'open', parts[0]))
        for m in re.finditer(r'\bh5py\.File\s*\(', code):
            args = call_args(code, m.end() - 1)
            parts = split_top(args)
            mode = strip_q(parts[1]) if len(parts) > 1 else 'r'
            if re.search(r'[wax+]', mode):
                writes.append((m.start(), 'h5py.File', parts[0]))
        for m in re.finditer(r'(' + P_WRITE + r')\s*\(', code):
            fn = m.group(1)
            args = call_args(code, m.end() - 1)
            if fn.startswith('.'):
                # method calls (.mkdir/.unlink/...) act on the object to their left; for
                # .savefig/.to_csv/... the path is the first argument
                if fn in ('.savefig', '.to_csv', '.to_parquet', '.to_pickle', '.to_excel', '.to_hdf',
                          '.to_json', '.to_feather', '.to_netcdf', '.to_zarr', '.tofile'):
                    writes.append((m.start(), fn, split_top(args)[0]))
                else:
                    left = re.split(r'[\n;=]', code[max(0, m.start() - 200):m.start()])[-1]
                    writes.append((m.start(), fn, left + ' ' + args))
            else:
                writes.append((m.start(), fn, args))
        for m in re.finditer(r'\b(shutil\.(?:copy|copy2|copyfile|copytree|unpack_archive))\s*\(', code):
            parts = split_top(call_args(code, m.end() - 1))
            writes.append((m.start(), m.group(1), parts[1] if len(parts) > 1 else ''))
        for m in re.finditer(r'\b(?:subprocess\.(?:run|call|Popen|check_call|check_output)|os\.system)\s*\(', code):
            args = call_args(code, m.end() - 1)
            lits = [a or b for a, b in re.findall(r"'([^']*)'|\"([^\"]*)\"", args)]
            if lits:
                shell_check(' '.join(lits), dict(ctx, cwd_srv=cd_at(cds, m.start())), depth + 1)
                if any(SERVER.search(x) for x in lits) and re.search(r'\b(rm|del|mv|move|mkdir|Remove-Item|Move-Item|New-Item|Set-Content|Out-File)\b', ' '.join(lits)):
                    block('subprocess call writes to a server: ' + ' '.join(lits)[:200])
    for pos, fn, argtext in writes:
        if is_srv_text(argtext, T.at(pos)):
            block('%s(...) writes to a server path: %s' % (fn, argtext.strip()[:200]))
        if cd_at(cds, pos):
            block('code changes directory into a server and then writes (%s)' % fn)
    # one level into repo scripts called by name from MATLAB code
    if lang == 'm' and depth == 0:
        for name in called_scripts(code):
            path = find_script(name, ctx.get('roots', []))
            if path:
                try:
                    txt = open(path, encoding='utf-8', errors='replace').read()
                except OSError:
                    continue
                try:
                    code_check(txt, 'm', ctx, depth + 1)
                except Blocked as e:
                    block('called script %s: %s' % (os.path.basename(path), e))


def cd_at(cds, pos):
    """True if the last cd before pos went into a server."""
    last = False
    for p, srv_ in cds:
        if p <= pos:
            last = srv_
    return last


def called_scripts(code):
    cands = set()
    for m in re.finditer(r'\b(?:run|evalc|eval|evalin\s*\(\s*\'base\'\s*,)\s*\(?\s*[\'"]([^\'"]+)[\'"]', code):
        s = m.group(1).strip()
        s = re.sub(r"^run\(\s*'?|'?\)\s*;?$", '', s)
        cands.add(os.path.splitext(os.path.basename(s.replace('\\', '/')))[0])
    for line in code.splitlines():
        for stmt in split_top(line, seps=(';', ',')):
            st = stmt.strip()
            if re.fullmatch(r'[A-Za-z]\w*', st):
                cands.add(st)
    return {c for c in cands if re.fullmatch(r'[A-Za-z]\w*', c)}


def find_script(name, roots):
    seen = set()
    for r in roots:
        if not r or r in seen or not os.path.isdir(r):
            continue
        seen.add(r)
        p = os.path.join(r, name + '.m')
        if os.path.isfile(p):
            return p
        try:
            for d in os.listdir(r):
                q = os.path.join(r, d, name + '.m')
                if os.path.isfile(q):
                    return q
        except OSError:
            pass
    return None


# ---------------------------------------------------------------- shell (Bash / PowerShell / cmd)
READ_VERBS = {'ls', 'dir', 'cat', 'type', 'head', 'tail', 'less', 'more', 'grep', 'egrep', 'fgrep', 'rg',
              'find', 'stat', 'du', 'df', 'wc', 'file', 'diff', 'cmp', 'md5sum', 'sha1sum', 'sha256sum',
              'xxd', 'od', 'hexdump', 'strings', 'test', '[', 'echo', 'printf', 'realpath', 'readlink',
              'basename', 'dirname', 'sort', 'uniq', 'cut', 'jq', 'awk', 'sed', 'perl', 'tree', 'column',
              'get-childitem', 'gci', 'get-content', 'gc', 'get-item', 'gi', 'get-itemproperty', 'gp',
              'test-path', 'select-string', 'sls', 'resolve-path', 'rvpa', 'measure-object', 'measure',
              'get-acl', 'get-filehash', 'format-table', 'ft', 'format-list', 'fl', 'where-object', 'where',
              '?', 'select-object', 'select', 'sort-object', 'write-output', 'write-host', 'echo', 'net',
              'split-path', 'join-path', 'get-psdrive', 'out-string', 'out-host', 'convertfrom-json',
              'import-csv', 'certutil', 'fc', 'findstr', 'more.com', 'true', 'false', 'exit', 'sleep',
              'start-sleep', 'wait', 'pwd', 'get-location', 'gl', 'which', 'where.exe', 'get-command'}
WRITE_VERBS = {'rm', 'rmdir', 'unlink', 'mkdir', 'touch', 'truncate', 'chmod', 'chown', 'chgrp', 'ln',
               'shred', 'mv', 'move', 'move-item', 'mi', 'ren', 'rename', 'rename-item', 'rni', 'del',
               'erase', 'rd', 'md', 'remove-item', 'ri', 'new-item', 'ni', 'set-content', 'sc',
               'add-content', 'ac', 'clear-content', 'clc', 'out-file', 'tee', 'tee-object',
               'set-itemproperty', 'sp', 'new-itemproperty', 'remove-itemproperty', 'expand-archive',
               'compress-archive', 'dd', 'patch', 'mklink', 'attrib', 'icacls', 'takeown', 'unzip', 'tar',
               '7z', 'zip', 'curl', 'wget', 'invoke-webrequest', 'iwr', 'start-bitstransfer', 'export-csv',
               'epcsv', 'export-clixml', 'set-acl', 'new-psdrive', 'subst', 'install'}
COPY_VERBS = {'cp', 'copy', 'copy-item', 'cpi', 'cpp', 'robocopy', 'xcopy', 'rsync', 'scp'}
CD_VERBS = {'cd', 'pushd', 'set-location', 'sl', 'push-location', 'chdir'}
GIT_READ = {'status', 'log', 'show', 'diff', 'blame', 'ls-files', 'rev-parse', 'describe', 'cat-file',
            'grep', 'shortlog', 'ls-tree', 'remote', 'config', 'branch', 'tag', 'reflog', 'fetch'}
INTERP = {'python', 'python3', 'py', 'pythonw', 'matlab', 'octave', 'bash', 'sh', 'zsh', 'pwsh',
          'powershell', 'cmd', 'node', 'rscript'}
WRAPPERS = {'sudo', 'env', 'xargs', 'time', 'nohup', 'command', 'builtin', 'exec', '&', '.', 'call',
            'start', 'start-process', 'invoke-expression', 'iex', 'foreach-object', '%'}


def split_shell(cmd):
    """-> list of (segment, sep_before) split on ; && || | & newline outside quotes."""
    segs, cur, q, i, sep = [], '', None, 0, ''
    while i < len(cmd):
        ch = cmd[i]
        if q:
            cur += ch
            if ch == q:
                q = None
            i += 1
            continue
        if ch in '"\'':
            q = ch
            cur += ch
            i += 1
            continue
        two = cmd[i:i + 2]
        if two in ('&&', '||'):
            segs.append((cur, sep)); cur, sep = '', two; i += 2; continue
        if ch == '|' and not (i > 0 and cmd[i - 1] in '>'):
            segs.append((cur, sep)); cur, sep = '', '|'; i += 1; continue
        if ch in ';\n':
            segs.append((cur, sep)); cur, sep = '', ch; i += 1; continue
        if ch == '&' and not (i > 0 and cmd[i - 1] in '<>') and cmd[i + 1:i + 2] not in ('>', '1', '2') \
                and not (i > 0 and cmd[i - 1] == ' ' and cmd[i + 1:i + 2] == ' ' and cur.strip() == ''):
            # PowerShell call operator '& "x"' at segment start is kept in the segment
            if cur.strip() == '':
                cur += ch; i += 1; continue
            segs.append((cur, sep)); cur, sep = '', '&'; i += 1; continue
        cur += ch
        i += 1
    segs.append((cur, sep))
    return [(s, p) for s, p in segs if s.strip()]


def tokens(seg):
    return [strip_q(t) for t in re.findall(r'"[^"]*"|\'[^\']*\'|\S+', seg)]


def shell_check(cmd, ctx, depth=0):
    if depth > 3:
        return
    taint = set()
    for m in re.finditer(r'(?:^|[\s;&|(])(?:export\s+|set\s+)?([A-Za-z_]\w*)=("[^"]*"|\'[^\']*\'|[^\s;&|]+)', cmd):
        if SERVER.search(m.group(2)):
            taint.add(m.group(1))
    for m in re.finditer(r'\$(?:env:)?([A-Za-z_]\w*)\s*=\s*([^;\n]+)', cmd, re.I):
        if SERVER.search(m.group(2)):
            taint.add(m.group(1))
    for _ in range(3):   # propagate: B="$A/x"
        for m in re.finditer(r'(?:^|[\s;&|(])(?:export\s+)?([A-Za-z_]\w*)=("[^"]*"|\'[^\']*\'|[^\s;&|]+)', cmd):
            if any(re.search(r'\$\{?' + re.escape(v) + r'\b', m.group(2)) for v in taint):
                taint.add(m.group(1))

    def srv(s):
        return bool(SERVER.search(s)) or any(
            re.search(r'\$\{?(?:env:)?' + re.escape(v) + r'\b', s, re.I) for v in taint)

    cd_srv = ctx.get('cwd_srv', False)
    pipe_srv = False
    for seg, sep in split_shell(cmd):
        if sep != '|':
            pipe_srv = False
        s_srv = srv(seg)
        # redirections into a server
        for m in re.finditer(r'(?:^|[^<>&\d=-])(\d?>>?|&>>?|>\|)\s*("[^"]*"|\'[^\']*\'|[^\s;|&)]+)', seg):
            tgt = strip_q(m.group(2))
            if srv(tgt) or (cd_srv and not re.match(r'(/dev/null|\$null|nul|[A-Za-z]:[\\/]|/[a-y]/|~|/tmp)', tgt, re.I)
                            and not tgt.startswith('&')):
                block('redirect writes to a server: %s' % seg.strip()[:200])
        toks = tokens(seg)
        while toks and (toks[0].lower() in WRAPPERS or re.fullmatch(r'[A-Za-z_]\w*=.*', toks[0])
                        or toks[0].startswith('-') and toks[0].lower() in ('-n', '-i')):
            toks = toks[1:]
        if not toks:
            continue
        verb = os.path.basename(toks[0].replace('\\', '/')).lower()
        if verb.endswith('.exe'):
            verb = verb[:-4]
        args = toks[1:]
        if pipe_srv and any(w in WRITE_VERBS for w in (t.lower() for t in toks)) and verb not in READ_VERBS - {'sed', 'perl'}:
            block('pipeline feeds server items into a write: %s' % seg.strip()[:200])
        if pipe_srv and re.search(r'\b(' + '|'.join(re.escape(w) for w in WRITE_VERBS if len(w) > 3) + r')\b', seg, re.I):
            block('pipeline feeds server items into a write: %s' % seg.strip()[:200])
        if s_srv:
            pipe_srv = True
        if verb in CD_VERBS:
            if args and srv(' '.join(args)):
                cd_srv = True
            elif args:
                cd_srv = False
            continue
        if verb == 'git':
            sub = next((a for a in args if not a.startswith('-') and not srv(a)
                        and a not in ('-C',)), '')
            if (s_srv or cd_srv) and sub.lower() not in GIT_READ:
                block('git %s on a server repository' % sub)
            continue
        if verb in INTERP:
            inline = None
            for flag in ('-c', '-batch', '-r', '-command', '/c', '-e', '/k'):
                if flag in [a.lower() for a in args]:
                    i = [a.lower() for a in args].index(flag)
                    inline = ' '.join(args[i + 1:]) if verb in ('pwsh', 'powershell', 'cmd') else (args[i + 1] if i + 1 < len(args) else '')
                    break
            lang = 'm' if verb in ('matlab', 'octave') else ('py' if verb.startswith('py') else 'sh')
            if inline is not None:
                if lang == 'sh':
                    shell_check(inline, dict(ctx, cwd_srv=cd_srv), depth + 1)
                else:
                    code_check(inline, lang, dict(ctx, cwd_srv=cd_srv), depth + 1)
            for a in args:
                ext = os.path.splitext(a)[1].lower()
                if ext in ('.py', '.m', '.sh', '.bash', '.ps1'):
                    p = a if os.path.isabs(a) else os.path.join(ctx.get('cwd') or '.', a)
                    if srv(a) and not os.path.isfile(p):
                        block('runs a script that lives on a server: %s' % a)
                    try:
                        txt = open(p, encoding='utf-8', errors='replace').read()
                    except OSError:
                        continue
                    sub_ctx = dict(ctx, cwd_srv=cd_srv)
                    try:
                        if ext == '.py':
                            code_check(txt, 'py', sub_ctx, depth + 1)
                        elif ext == '.m':
                            code_check(txt, 'm', sub_ctx, depth + 1)
                        else:
                            shell_check(txt, sub_ctx, depth + 1)
                    except Blocked as e:
                        block('script %s: %s' % (os.path.basename(a), e))
            continue
        if verb in COPY_VERBS:
            pos = [a for a in args if not a.startswith('-') and not (verb in ('robocopy', 'xcopy') and a.startswith('/'))]
            dest = ''
            low = [a.lower() for a in args]
            for flag in ('-destination', '-dest', '-d'):
                if flag in low and low.index(flag) + 1 < len(args):
                    dest = args[low.index(flag) + 1]
            if not dest and pos:
                dest = pos[1] if verb in ('robocopy', 'xcopy', 'copy-item', 'cpi', 'copy') and len(pos) > 1 else pos[-1]
            if '-t' in low and low.index('-t') + 1 < len(args):
                dest = args[low.index('-t') + 1]
            if srv(dest) or (cd_srv and dest and not re.match(r'([A-Za-z]:[\\/]|/[a-y]/|~|/tmp|\\\\)', dest)):
                block('copies INTO a server: %s' % seg.strip()[:200])
            if verb in ('rsync',) and '--remove-source-files' in low and s_srv:
                block('rsync --remove-source-files on a server')
            continue
        if verb in ('sed', 'perl'):
            if (s_srv or cd_srv) and any(a.startswith('-i') or a.startswith('-pi') for a in args):
                block('%s -i edits a server file in place' % verb)
            continue
        if verb == 'find':
            if (s_srv or cd_srv) and any(a in ('-delete', '-exec', '-execdir', '-ok', '-okdir', '-fprint', '-fprintf', '-fls') for a in args):
                block('find with -delete/-exec on a server')
            continue
        if verb in WRITE_VERBS:
            if s_srv or cd_srv:
                block('%s on a server path: %s' % (verb, seg.strip()[:200]))
            continue
        if re.search(r'\[(?:System\.)?IO\.(?:File|Directory)\]::(?:Write|Append|Create|Delete|Move|Copy|Replace|Set)', seg, re.I) and (s_srv or cd_srv):
            block('.NET file write on a server: %s' % seg.strip()[:200])
        if verb in READ_VERBS:
            continue
        if s_srv or (cd_srv and verb not in READ_VERBS):
            block('unrecognised command "%s" touches a server path; only read commands are allowed there' % verb)


# ---------------------------------------------------------------- main
def check(data):
    tool = data.get('tool_name', '')
    ti = data.get('tool_input', {}) or {}
    cwd = data.get('cwd') or os.getcwd()
    roots = [ti.get('project_path'), os.environ.get('CLAUDE_PROJECT_DIR'), cwd]
    ctx = {'cwd': cwd, 'cwd_srv': bool(SERVER.search(cwd or '')), 'roots': [r for r in roots if r]}
    if tool in ('Bash', 'PowerShell') and SELFTEST in (ti.get('command') or ''):
        block('self-test marker seen: the server read-only guard is active')
    if tool in ('Write', 'Edit', 'MultiEdit', 'NotebookEdit'):
        p = ti.get('file_path') or ti.get('notebook_path') or ''
        if SERVER.search(p) or (ctx['cwd_srv'] and not os.path.isabs(p)):
            block('%s targets a server file: %s' % (tool, p))
        return
    if tool in ('Bash', 'PowerShell'):
        shell_check(ti.get('command', ''), ctx)
        return
    if tool.startswith('mcp__matlab__'):
        pp = ti.get('project_path') or ''
        if pp and SERVER.search(pp):
            ctx['cwd_srv'] = True
        if 'code' in ti:
            code_check(ti.get('code') or '', 'm', ctx)
        for k in ('script_path', 'file_path', 'filePath', 'test_file'):
            p = ti.get(k)
            if p:
                if SERVER.search(p):
                    block('runs a MATLAB file that lives on a server: %s' % p)
                try:
                    txt = open(p, encoding='utf-8', errors='replace').read()
                except OSError:
                    continue
                code_check(txt, 'm', ctx)
        return


def log(tool, reason):
    try:
        lp = os.path.join(os.path.expanduser('~'), '.claude', 'hooks', 'server_guard.log')
        os.makedirs(os.path.dirname(lp), exist_ok=True)
        with open(lp, 'a', encoding='utf-8') as f:
            f.write('%s\t%s\t%s\n' % (time.strftime('%Y-%m-%d %H:%M:%S'), tool, reason.replace('\n', ' ')[:400]))
    except Exception:
        pass


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except Exception:
        if SERVER.search(raw):
            sys.stderr.write('BLOCKED (server read-only guard): could not parse the tool input, and it names a lab server.\n')
            sys.exit(2)
        sys.exit(0)
    try:
        check(data)
    except Blocked as e:
        msg = ('BLOCKED by the server read-only guard (.claude/hooks/server_readonly_guard.py): %s\n'
               'Lab servers (\\\\sahale..., \\\\steinmetzsuper1..., zserver, \\\\tower / Z:) are READ-ONLY for Claude. '
               'Never write, move, rename or delete there. If this was meant as a read, restructure it '
               '(copy server -> local, or read with ls / cat / np.load); otherwise ask the user to do it.\n' % e)
        log(data.get('tool_name', '?'), str(e))
        sys.stderr.write(msg)
        sys.exit(2)
    except Exception as e:   # guard bug: fail closed only if the input names a server
        if SERVER.search(raw):
            sys.stderr.write('BLOCKED (server read-only guard internal error %r) because the input names a lab server.\n' % e)
            log(data.get('tool_name', '?'), 'internal error %r' % e)
            sys.exit(2)
    sys.exit(0)


if __name__ == '__main__':
    main()
