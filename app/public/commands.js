// Command palette — drop-up from the unified chat input
(function() {
  const COMMANDS = [
    { id: 'sprint-status',    label: 'Sprint Status',          desc: 'Current sprint dashboard',                   category: 'Scrum Master', action: 'Show sprint status for {team}' },
    { id: 'bug-triage',       label: 'Bug Triage',             desc: 'Bug triage session',                         category: 'Scrum Master', action: 'Run bug triage for {team}' },
    { id: 'standup',          label: 'Standup',                desc: 'Weekly standup prep',                        category: 'Scrum Master', action: 'Prepare standup for {team}' },
    { id: 'sprint-plan',      label: 'Sprint Plan',            desc: 'Sprint planning preparation',                category: 'Scrum Master', action: 'Sprint planning prep for {team}' },
    { id: 'sprint-review',    label: 'Sprint Review',          desc: 'Sprint review summary',                      category: 'Scrum Master', action: 'Sprint review summary for {team}' },
    { id: 'carryovers',       label: 'Carryovers',             desc: 'Carryover analysis',                         category: 'Scrum Master', action: 'Carryover analysis for {team}' },
    { id: 'team-load',        label: 'Team Load',              desc: 'Workload distribution across team',          category: 'Scrum Master', action: 'Show team workload for {team}' },
    { id: 'release-check',    label: 'Release Check',          desc: 'Release readiness check',                    category: 'Scrum Master', action: 'Release readiness check for {team}' },
    { id: 'team-member',      label: 'Team Member',            desc: 'Individual Jira activity summary',           category: 'Scrum Master', arg: 'name',  prompt: 'Team member name:' },
    { id: 'team-member-gh',   label: 'Team Member GitHub',     desc: 'Individual GitHub activity summary',         category: 'Scrum Master', arg: 'handle', prompt: 'GitHub handle:' },
    { id: 'standup-github',   label: 'Standup GitHub',         desc: 'GitHub activity for all team members',       category: 'Scrum Master', action: 'Show GitHub activity for all {team} members' },
    { id: 'my-board',         label: 'My Board',               desc: 'My assigned sprint items by status',         category: 'Team Member', action: 'Show my board for {team}' },
    { id: 'my-bugs',          label: 'My Bugs',                desc: 'My bugs by severity and customer impact',    category: 'Team Member', action: 'Show my bugs for {team}' },
    { id: 'my-epics',         label: 'My Epics',               desc: 'Epic progress I\'m contributing to',         category: 'Team Member', action: 'Show my epic progress for {team}' },
    { id: 'my-standup',       label: 'My Standup',             desc: 'Personal standup talking points',            category: 'Team Member', action: 'My standup talking points for {team}' },
    { id: 'my-prs',           label: 'My PRs',                 desc: 'My open PRs + review requests for me',       category: 'Team Member', action: 'Show my PRs' },
    { id: 'my-github-issues', label: 'My GitHub Issues',       desc: 'GitHub issues authored, assigned, commented', category: 'Team Member', action: 'Show my GitHub issues' },
    { id: 'review-queue',     label: 'Review Queue',           desc: 'PRs awaiting my review, prioritized',        category: 'Team Member', action: 'Show my review queue' },
    { id: 'pickup',           label: 'Pickup',                 desc: 'Find unassigned work to grab',               category: 'Team Member', action: 'Find unassigned work for {team}' },
    { id: 'investigate',      label: 'Investigate',            desc: 'Deep dive on a single issue',                category: 'Issue', arg: 'key', prompt: 'Issue key (e.g. OCPNODE-1234):' },
    { id: 'briefing',         label: 'Briefing',               desc: 'Get up to speed on an issue fast',           category: 'Issue', arg: 'key', prompt: 'Issue key:' },
    { id: 'update',           label: 'Update',                 desc: 'Comment, transition, or set points',         category: 'Issue', arg: 'key', prompt: 'Issue key:' },
    { id: 'blocker',          label: 'Blocker',                desc: 'Flag/unflag a blocker on an issue',          category: 'Issue', arg: 'key', prompt: 'Issue key:' },
    { id: 'handoff',          label: 'Handoff',                desc: 'Prepare a handoff summary for transfer',     category: 'Issue', arg: 'key', prompt: 'Issue key:' },
  ];

  const HINT_HTML = '<div class="cmd-hint"><kbd>/</kbd> Filter commands, <kbd>\u2191</kbd><kbd>\u2193</kbd> navigate, <kbd>Enter</kbd> select, <kbd>Esc</kbd> dismiss</div>';

  const input = document.getElementById('user-input');
  const dropdown = document.getElementById('cmd-dropdown');
  const teamSelector = document.getElementById('team-selector');
  const esc = window._escapeHtml;

  let selectedIdx = 0;
  let filtered = COMMANDS;
  let isOpen = false;
  let lastQuery = null;

  const COMMANDS_BY_ID = Object.fromEntries(COMMANDS.map(c => [c.id, c]));
  const ARG_CMD_IDS = new Set(COMMANDS.filter(c => c.arg).map(c => c.id));
  const SLASH_RE = /^\/(\S+)\s*(.*)/;

  window._transformSlashCommand = function(text) {
    const match = text.match(SLASH_RE);
    if (!match) return null;
    const cmd = COMMANDS_BY_ID[match[1]];
    if (!cmd) return null;
    const arg = match[2]?.trim();
    if (cmd.arg && arg) {
      return `${cmd.label} ${arg}`;
    }
    if (cmd.action && !cmd.arg) {
      return cmd.action.replace('{team}', teamSelector.value);
    }
    return null;
  };

  function open() {
    if (isOpen) return;
    isOpen = true;
    dropdown.classList.remove('hidden');
  }

  function close() {
    isOpen = false;
    dropdown.classList.add('hidden');
    selectedIdx = 0;
    lastQuery = null;
  }

  function render(query) {
    if (query === lastQuery) {
      updateSelection();
      return;
    }
    lastQuery = query;

    const q = query.toLowerCase().trim();
    filtered = q
      ? COMMANDS.filter(c =>
          c.id.includes(q) || c.label.toLowerCase().includes(q) || c.desc.toLowerCase().includes(q) || c.category.toLowerCase().includes(q)
        )
      : COMMANDS;

    if (selectedIdx >= filtered.length) selectedIdx = Math.max(0, filtered.length - 1);

    let html = HINT_HTML;
    let lastCategory = '';
    filtered.forEach((cmd, i) => {
      if (cmd.category !== lastCategory) {
        lastCategory = cmd.category;
        html += `<div class="cmd-category">${esc(cmd.category)}</div>`;
      }
      const selected = i === selectedIdx ? ' cmd-selected' : '';
      const argHint = cmd.arg ? `<span class="cmd-arg">&lt;${cmd.arg}&gt;</span>` : '';
      html += `<div class="cmd-item${selected}" data-idx="${i}">
        <span class="cmd-name">/${esc(cmd.id)}</span>${argHint}
        <span class="cmd-desc">${esc(cmd.desc)}</span>
      </div>`;
    });

    if (!filtered.length) {
      html += '<div class="cmd-empty">No matching commands</div>';
    }

    dropdown.innerHTML = html;
    scrollToSelected();
  }

  function updateSelection() {
    const prev = dropdown.querySelector('.cmd-selected');
    if (prev) prev.classList.remove('cmd-selected');
    const items = dropdown.querySelectorAll('.cmd-item');
    if (items[selectedIdx]) {
      items[selectedIdx].classList.add('cmd-selected');
      items[selectedIdx].scrollIntoView({ block: 'nearest' });
    }
  }

  function scrollToSelected() {
    const sel = dropdown.querySelector('.cmd-selected');
    if (sel) sel.scrollIntoView({ block: 'nearest' });
  }

  function execute(cmd) {
    close();
    const team = teamSelector.value;

    if (cmd.arg) {
      // Put "/cmd-id " in the input — user types the arg and presses Enter
      input.value = `/${cmd.id} `;
      input.focus();
      return;
    }

    input.value = '';
    if (cmd.action) {
      window.sendChatMessage(cmd.action.replace('{team}', team));
    }
  }

  function activateCommandMode() {
    input.focus();
    input.value = '/';
    input.dispatchEvent(new Event('input'));
  }

  function isTypingArg(val) {
    const match = val.match(/^\/(\S+)\s+/);
    return match ? ARG_CMD_IDS.has(match[1]) : false;
  }

  input.addEventListener('input', () => {
    const val = input.value;
    if (val.startsWith('/')) {
      if (isTypingArg(val)) {
        // User is typing an argument after a known command — suppress palette
        if (isOpen) close();
        return;
      }
      const q = val.slice(1);
      selectedIdx = 0;
      if (!isOpen) open();
      render(q);
    } else if (isOpen) {
      close();
    }
  });

  input.addEventListener('keydown', (e) => {
    if (!isOpen) return;

    if (e.key === 'Escape') {
      e.preventDefault();
      close();
      input.value = '';
      return;
    }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      selectedIdx = Math.min(selectedIdx + 1, filtered.length - 1);
      updateSelection();
      return;
    }
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      selectedIdx = Math.max(selectedIdx - 1, 0);
      updateSelection();
      return;
    }
    if (e.key === 'Enter' && filtered.length) {
      e.preventDefault();
      execute(filtered[selectedIdx]);
      return;
    }
  });

  dropdown.addEventListener('mousedown', (e) => {
    const item = e.target.closest('.cmd-item');
    if (item) {
      e.preventDefault();
      execute(filtered[parseInt(item.dataset.idx)]);
    }
  });

  document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      activateCommandMode();
      return;
    }
    if (e.key === '/' && !['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) {
      e.preventDefault();
      activateCommandMode();
    }
  });
})();
