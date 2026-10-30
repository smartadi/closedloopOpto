// Export an Overleaf project's review comments and tracked changes to Markdown.
//
// Usage: open the project in Overleaf (signed in), press F12 -> Console, paste this whole
// file, press Enter. A file <project>_review_<date>.md downloads.
// Change the argument of the last line to filter by reviewer: a fragment of their
// first name, last name or email ('steinme' = Nick); '' keeps everyone.
//
// Read-only: it calls the same endpoints the Overleaf editor uses
// (/project/<id>/threads, /project/<id>/ranges, /Project/<id>/doc/<doc>/download).
// Line numbers are in Overleaf's current text, with tracked insertions present and
// tracked deletions absent. Comment anchors and change positions are where Overleaf
// stores them; resolved threads are kept and flagged.

window.olExport = async (author = '', opts = {}) => {
  const pid = location.pathname.split('/')[2];
  const get = async (u) => {
    const r = await fetch(u, { credentials: 'include' });
    if (!r.ok) throw new Error(`${u} -> HTTP ${r.status}`);
    return r;
  };
  const name = (u) => (u ? `${u.first_name || ''} ${u.last_name || ''}`.trim() || u.email || '?' : '?');
  const matches = (u) =>
    !author || [u?.first_name, u?.last_name, u?.email].join(' ').toLowerCase().includes(author.toLowerCase());
  const stamp = (ts) => new Date(ts).toISOString().slice(0, 16).replace('T', ' ') + ' UTC';
  const quote = (s) => s.split('\n').map((l) => '> ' + l).join('\n');

  const threads = await (await get(`/project/${pid}/threads`)).json();
  const ranges = await (await get(`/project/${pid}/ranges`)).json();

  // Tracked changes carry only a user id; names come from the comment threads.
  const users = {};
  for (const th of Object.values(threads))
    for (const m of th.messages || []) if (m.user) users[m.user_id || m.user.id] = m.user;

  const comments = [];
  const changes = [];
  for (const d of ranges) {
    const rc = d.ranges || {};
    if (!(rc.comments || []).length && !(rc.changes || []).length) continue;
    const r = await get(`/Project/${pid}/doc/${d.id}/download`);
    const m = (r.headers.get('content-disposition') || '').match(/filename\*?=(?:UTF-8'')?"?([^";]+)"?/i);
    const file = m ? decodeURIComponent(m[1]) : d.id;
    const text = await r.text();
    const lines = text.split('\n');
    const lineOf = (p) => text.slice(0, p).split('\n').length;

    for (const c of rc.comments || []) {
      const th = threads[c.op.t];
      if (!th || !(th.messages || []).length || !matches(th.messages[0].user)) continue;
      comments.push({ file, line: lineOf(c.op.p), anchor: c.op.c, resolved: !!th.resolved, msgs: th.messages });
    }
    for (const ch of rc.changes || []) {
      const u = users[ch.metadata?.user_id];
      if (author && !matches(u)) continue;
      const line = lineOf(ch.op.p);
      changes.push({
        file, line, now: lines[line - 1], who: name(u), ts: ch.metadata?.ts,
        kind: ch.op.i !== undefined ? 'inserted' : 'deleted', text: ch.op.i ?? ch.op.d,
      });
    }
  }

  const byPos = (a, b) => a.file.localeCompare(b.file) || a.line - b.line;
  comments.sort(byPos);
  changes.sort(byPos);

  const project = document.title.split(' - ')[0];
  const today = new Date().toISOString().slice(0, 10);
  const md = [
    `# Overleaf review export: ${project}`,
    '',
    `Exported ${today}${author ? `, reviewer filter "${author}"` : ''}. ` +
      `${comments.length} comment threads, ${changes.length} tracked changes.`,
    '',
    '## Comments',
    '',
  ];
  comments.forEach((c, k) => {
    md.push(`### C${k + 1} · ${c.file}:${c.line}${c.resolved ? ' · RESOLVED' : ''}`, '', quote(c.anchor), '');
    for (const m of c.msgs) md.push(`- **${name(m.user)}** (${stamp(m.timestamp)}): ${m.content}`);
    md.push('');
  });
  md.push('## Tracked changes, grouped by line', '');
  let key = '';
  for (const ch of changes) {
    const k = `${ch.file}:${ch.line}`;
    if (k !== key) {
      key = k;
      md.push('', `### ${k}`, '', 'Line now (insertions applied, deletions removed):', '', quote(ch.now || ''), '');
    }
    md.push(`- ${ch.kind} by ${ch.who}: \`${ch.text.replace(/`/g, "'")}\``);
  }
  const out = md.join('\n') + '\n';

  if (opts.dry) return out;
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([out], { type: 'text/markdown' }));
  a.download = `${project.replace(/[^\w.-]+/g, '_')}_review_${today}.md`;
  a.click();
  console.log(`olExport: ${comments.length} comments, ${changes.length} tracked changes -> ${a.download}`);
  return `${comments.length} comments, ${changes.length} tracked changes`;
};

olExport('steinme');
