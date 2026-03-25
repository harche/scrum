// Rich UI component renderers for Jira and GitHub data
(function() {
  const JIRA_URL = 'https://redhat.atlassian.net/browse/';

  // ── Dispatch ───────────────────────────────────────────────────────────
  window.renderComponent = function(container, type, data) {
    const renderers = {
      sprint_dashboard: renderSprintDashboard,
      bug_overview: renderBugOverview,
      issue_deep_dive: renderIssueCard,
      standup_data: renderStandupData,
      epic_progress: renderEpicProgress,
      my_board: renderMyBoard,
      my_bugs: renderBugOverview,
      carryover_report: renderCarryoverReport,
      planning_data: renderPlanningData,
      pickup_data: renderPickupData,
      release_data: renderReleaseData,
      team_prs: renderTeamPRs,
      member_prs: renderMemberPRs,
      my_prs: renderMyPRs,
      my_issues: renderMyIssues,
      review_queue: renderReviewQueue,
      my_standup: renderStandupData,
    };
    const renderer = renderers[type];
    if (renderer) {
      renderer(container, data);
    } else {
      container.innerHTML = `<pre>${JSON.stringify(data, null, 2)}</pre>`;
    }
  };

  // ── Helpers ────────────────────────────────────────────────────────────

  // Use shared escape from app.js
  const esc = window._escapeHtml || function(text) {
    const div = document.createElement('div');
    div.textContent = text || '';
    return div.innerHTML;
  };

  // Escape for use inside onclick single-quoted strings
  function escAttr(text) {
    return esc(text).replace(/'/g, '&#39;');
  }

  function jiraLink(key) {
    return `<span class="jira-key" onclick="event.stopPropagation(); window.sendChatMessage('Investigate ${escAttr(key)}')">${esc(key)}</span>`;
  }

  function jiraExtLink(key) {
    return `<a href="${JIRA_URL}${key}" target="_blank" rel="noopener" class="jira-ext-link" onclick="event.stopPropagation()" title="Open in Jira">&#8599;</a>`;
  }

  function statusBadge(status, group) {
    const cls = group || statusGroup(status);
    return `<span class="status-badge status-${cls}">${esc(status)}</span>`;
  }

  function statusGroup(status) {
    const s = (status || '').toLowerCase();
    if (s.includes('done') || s.includes('closed') || s.includes('verified')) return 'done';
    if (s.includes('review') || s.includes('post')) return 'codeReview';
    if (s.includes('progress') || s.includes('assigned')) return 'inProgress';
    if (s.includes('modified') || s.includes('on_qa')) return 'modified';
    if (s.includes('to do') || s.includes('new')) return 'toDo';
    return 'other';
  }

  function priorityIcon(priority) {
    const p = (priority || '').toLowerCase();
    if (p.includes('blocker') || p.includes('critical')) return '<span class="priority priority-critical" title="Critical/Blocker">!</span>';
    if (p.includes('major')) return '<span class="priority priority-major" title="Major">^</span>';
    return '';
  }

  function pointsPill(points) {
    if (!points && points !== 0) return '';
    return `<span class="points-pill">${points} pts</span>`;
  }

  function assigneeBadge(name) {
    if (!name || name === 'Unassigned') return '<span class="assignee unassigned">Unassigned</span>';
    return `<span class="assignee">${esc(name)}</span>`;
  }

  function progressBar(done, total, label) {
    const pct = total > 0 ? Math.round((done / total) * 100) : 0;
    return `<div class="progress-bar-container">
      ${label ? `<span class="progress-label">${esc(label)}</span>` : ''}
      <div class="progress-bar"><div class="progress-fill" style="width:${pct}%"></div></div>
      <span class="progress-text">${pct}%</span>
    </div>`;
  }

  function chip(label, count, cls) {
    return `<span class="chip chip-${cls || 'default'}">${esc(label)}: ${count}</span>`;
  }

  function issueRow(issue) {
    const blocked = issue.blocked ? '<span class="blocked-flag" title="Blocked">BLOCKED</span>' : '';
    const rb = issue.releaseBlocker ? '<span class="rb-flag" title="Release Blocker">RB</span>' : '';
    return `<div class="issue-row" onclick="window.sendChatMessage('Investigate ${escAttr(issue.key)}')" title="Click to investigate">
      <span class="issue-row-key">${jiraLink(issue.key)}${jiraExtLink(issue.key)}</span>
      ${statusBadge(issue.status, issue.statusGroup)}
      ${priorityIcon(issue.priority)}
      ${blocked}${rb}
      <span class="issue-row-summary">${esc(issue.summary)}</span>
      <span class="issue-row-right">
        ${assigneeBadge(issue.assignee)}
        ${pointsPill(issue.points)}
      </span>
    </div>`;
  }

  function collapsibleSection(title, count, contentHtml, open = false) {
    return `<details class="section-details" ${open ? 'open' : ''}>
      <summary>${esc(title)} <span class="section-count">(${count})</span></summary>
      <div class="section-body">${contentHtml}</div>
    </details>`;
  }

  // ── Sprint Dashboard ──────────────────────────────────────────────────

  function renderSprintDashboard(container, data) {
    const s = data.sprint || {};
    const sum = data.summary || {};

    let html = `<div class="component sprint-dashboard">
      <div class="component-header">
        <h3>${esc(s.name || 'Sprint')}</h3>
        ${progressBar(s.daysElapsed, s.daysTotal, `Day ${s.daysElapsed}/${s.daysTotal} (${s.daysRemaining} remaining)`)}
      </div>
      <div class="chip-row">
        ${chip('Done', sum.done, 'done')}
        ${chip('Code Review', sum.codeReview, 'codeReview')}
        ${chip('In Progress', sum.inProgress, 'inProgress')}
        ${chip('Modified', sum.modified, 'modified')}
        ${chip('To Do', sum.toDo, 'toDo')}
        ${chip('Total', sum.total, 'default')}
      </div>
      <div class="points-summary">
        ${progressBar(sum.donePoints, sum.totalPoints, `Story Points: ${sum.donePoints || 0}/${sum.totalPoints || 0}`)}
      </div>`;

    // Blockers
    if (data.blockers?.length) {
      html += `<div class="blockers-section">
        <h4>Blockers</h4>
        ${data.blockers.map(i => issueRow(i)).join('')}
      </div>`;
    }

    // At risk
    if (data.atRisk?.length) {
      html += collapsibleSection('At Risk', data.atRisk.length,
        data.atRisk.map(i => issueRow(i)).join(''));
    }

    // Status groups
    const groups = data.byStatus || {};
    for (const [group, label] of [['inProgress','In Progress'],['codeReview','Code Review'],['modified','Modified'],['toDo','To Do'],['done','Done']]) {
      const items = groups[group] || [];
      if (items.length) {
        html += collapsibleSection(label, items.length,
          items.map(i => issueRow(i)).join(''), group === 'inProgress');
      }
    }

    // Team workload
    if (data.teamWorkload?.length) {
      html += `<details class="section-details"><summary>Team Workload <span class="section-count">(${data.teamWorkload.length})</span></summary>
        <div class="section-body">
          <table class="workload-table">
            <thead><tr><th>Member</th><th>To Do</th><th>In Progress</th><th>Review</th><th>Done</th><th>Total</th><th>Points</th></tr></thead>
            <tbody>
              ${data.teamWorkload.map(m => `<tr class="workload-row" onclick="window.sendChatMessage('Show activity for ${escAttr(m.member)}')">
                <td>${esc(m.member)}</td>
                <td>${m.toDo || 0}</td>
                <td>${m.inProgress || 0}</td>
                <td>${m.codeReview || 0}</td>
                <td>${m.done || 0}</td>
                <td><strong>${m.total || 0}</strong></td>
                <td>${m.pointsDone || 0}/${m.pointsTotal || 0}</td>
              </tr>`).join('')}
            </tbody>
          </table>
        </div>
      </details>`;
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // ── Issue Card ────────────────────────────────────────────────────────

  function renderIssueCard(container, data) {
    const typeIcon = {
      Bug: 'bug', Story: 'story', Task: 'task', Epic: 'epic', 'Sub-task': 'subtask',
    }[data.type] || 'task';

    let html = `<div class="component issue-card">
      <div class="issue-card-header">
        <span class="issue-type issue-type-${typeIcon}">${esc(data.type)}</span>
        <span class="jira-key-large">${esc(data.key)}</span>${jiraExtLink(data.key)}
        ${statusBadge(data.status)}
        ${priorityIcon(data.priority)}
        ${data.blocked ? '<span class="blocked-flag">BLOCKED</span>' : ''}
        ${data.releaseBlocker ? '<span class="rb-flag">Release Blocker</span>' : ''}
      </div>
      <h3 class="issue-card-title">${esc(data.summary)}</h3>
      <div class="issue-card-meta">
        <span>Assignee: <strong>${esc(data.assignee || 'Unassigned')}</strong></span>
        <span>Points: <strong>${data.points || 'None'}</strong></span>
        ${data.epicKey ? `<span>Epic: ${jiraLink(data.epicKey)}${jiraExtLink(data.epicKey)}</span>` : ''}
        ${data.fixVersions?.length ? `<span>Version: ${data.fixVersions.join(', ')}</span>` : ''}
      </div>`;

    // Description
    if (data.description) {
      const desc = data.description.length > 500 ? data.description.slice(0, 500) + '...' : data.description;
      html += `<details class="section-details"><summary>Description</summary>
        <div class="section-body"><pre class="description-text">${esc(desc)}</pre></div>
      </details>`;
    }

    // Blocked reason
    if (data.blockedReason) {
      html += `<div class="blocked-reason"><strong>Blocked Reason:</strong> ${esc(data.blockedReason)}</div>`;
    }

    // Linked issues
    if (data.linkedIssues?.length) {
      html += collapsibleSection('Linked Issues', data.linkedIssues.length,
        data.linkedIssues.map(li =>
          `<div class="linked-issue">
            <span class="link-type">${esc(li.relationship)}</span>
            ${jiraLink(li.key)}${jiraExtLink(li.key)} ${statusBadge(li.status)} ${esc(li.summary)}
          </div>`
        ).join(''));
    }

    // Comments
    if (data.comments?.length) {
      html += collapsibleSection('Comments', data.comments.length,
        data.comments.slice(-5).map(c =>
          `<div class="comment">
            <div class="comment-header"><strong>${esc(c.author)}</strong> <span class="comment-date">${formatDate(c.created)}</span></div>
            <div class="comment-body">${esc(c.body?.slice(0, 300) || '')}</div>
          </div>`
        ).join(''), true);
    }

    // Dynamic action buttons
    html += `<div class="action-buttons">`;
    if (data.transitions?.length) {
      html += data.transitions.map(t =>
        `<button class="action-btn action-btn-transition" onclick="window.sendChatMessage('Transition ${escAttr(data.key)} to ${escAttr(t.name)} (transition ID: ${escAttr(t.id)})')">
          ${esc(t.name)}
        </button>`
      ).join('');
    }
    html += `<button class="action-btn action-btn-comment" onclick="promptComment('${escAttr(data.key)}')">Add Comment</button>
      <button class="action-btn action-btn-points" onclick="promptPoints('${escAttr(data.key)}')">Set Points</button>
      <a class="action-btn action-btn-jira" href="${JIRA_URL}${data.key}" target="_blank" rel="noopener">Open in Jira &#8599;</a>
    </div>`;

    // Customer escalation info
    if (data.sfdcCaseCount && data.sfdcCaseCount !== '0') {
      html += `<div class="escalation-info">Customer Escalation: ${esc(data.sfdcCaseCount)} case(s)</div>`;
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // Inline prompt helpers for action buttons
  window.promptComment = function(key) {
    const text = prompt('Enter comment text:');
    if (text) window.sendChatMessage(`Add comment to ${key}: "${text}"`);
  };
  window.promptPoints = function(key) {
    const pts = prompt('Enter story points:');
    if (pts) window.sendChatMessage(`Set story points on ${key} to ${pts}`);
  };

  // ── Bug Overview ──────────────────────────────────────────────────────

  function renderBugOverview(container, data) {
    const sum = data.summary || {};
    let html = `<div class="component bug-overview">
      <div class="component-header"><h3>Bug Overview</h3></div>
      <div class="chip-row">
        ${chip('Total Open', sum.totalOpen, 'default')}
        ${chip('Untriaged', sum.untriaged, 'toDo')}
        ${chip('Unassigned', sum.unassigned, 'modified')}
        ${chip('Blocker Proposals', sum.blockerProposals, 'codeReview')}
        ${chip('New This Week', sum.newThisWeek, 'inProgress')}
      </div>`;

    const sections = [
      ['Untriaged', data.untriaged],
      ['Unassigned', data.unassigned],
      ['Blocker Proposals', data.blockerProposals],
      ['New This Week', data.newThisWeek],
    ];

    for (const [title, items] of sections) {
      if (items?.length) {
        html += collapsibleSection(title, items.length,
          items.map(i => issueRow(i)).join(''),
          title === 'Untriaged');
      }
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // ── Standup Data ──────────────────────────────────────────────────────

  function renderStandupData(container, data) {
    // Reuse sprint dashboard for the sprint portion
    renderSprintDashboard(container, data);

    // Add per-assignee breakdown if present
    if (data.byAssignee) {
      const el = container.querySelector('.sprint-dashboard');
      if (!el) return;

      let html = '<h4 style="margin-top:12px">By Assignee</h4>';
      for (const [name, items] of Object.entries(data.byAssignee)) {
        if (items.length) {
          html += collapsibleSection(name, items.length,
            items.map(i => issueRow(i)).join(''));
        }
      }
      el.insertAdjacentHTML('beforeend', html);
    }
  }

  // ── Epic Progress ─────────────────────────────────────────────────────

  function renderEpicProgress(container, data) {
    let html = '<div class="component epic-progress"><div class="component-header"><h3>Epic Progress</h3></div>';

    for (const epic of (data.epics || [])) {
      const p = epic.progress || {};
      html += `<div class="epic-card">
        <div class="epic-header">
          ${jiraLink(epic.key)}
          <span class="epic-summary">${esc(epic.summary)}</span>
          ${statusBadge(epic.status)}
        </div>
        ${progressBar(p.done, p.total, `${p.done}/${p.total} done`)}
        <div class="chip-row">
          ${chip('Done', p.done, 'done')}
          ${chip('In Progress', p.inProgress, 'inProgress')}
          ${chip('To Do', p.toDo, 'toDo')}
        </div>`;

      if (epic.myItems?.length) {
        html += collapsibleSection('My Items', epic.myItems.length,
          epic.myItems.map(i => issueRow(i)).join(''), true);
      }
      if (epic.otherItems?.length) {
        html += collapsibleSection('Other Items', epic.otherItems.length,
          epic.otherItems.map(i => issueRow(i)).join(''));
      }
      html += '</div>';
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // ── My Board (reuses sprint dashboard with filtered data) ─────────────

  function renderMyBoard(container, data) {
    renderSprintDashboard(container, data);
  }

  // ── Carryover Report ──────────────────────────────────────────────────

  function renderCarryoverReport(container, data) {
    let html = '<div class="component carryover-report"><div class="component-header"><h3>Carryover Analysis</h3></div>';

    const items = data.carryovers || data.items || [];
    if (items.length) {
      html += items.map(i => issueRow(i)).join('');
    } else {
      html += '<p class="empty-state">No carryover items found.</p>';
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // ── Planning Data ─────────────────────────────────────────────────────

  function renderPlanningData(container, data) {
    let html = '<div class="component planning-data"><div class="component-header"><h3>Sprint Planning</h3></div>';

    const sections = [
      ['Carryovers', data.carryovers],
      ['Scheduled', data.scheduled],
      ['Backlog', data.backlog],
      ['Unscheduled Bugs', data.unscheduledBugs],
    ];

    for (const [title, items] of sections) {
      if (items?.length) {
        html += collapsibleSection(title, items.length,
          items.map(i => issueRow(i)).join(''),
          title === 'Carryovers');
      }
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // ── Pickup Data ───────────────────────────────────────────────────────

  function renderPickupData(container, data) {
    let html = '<div class="component pickup-data"><div class="component-header"><h3>Available Work</h3></div>';

    const sections = [
      ['Sprint Items', data.sprintItems || data.unassignedSprint],
      ['Bugs', data.bugs || data.unassignedBugs],
    ];

    for (const [title, items] of sections) {
      if (items?.length) {
        html += collapsibleSection(title, items.length,
          items.map(i => issueRow(i)).join(''), true);
      }
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // ── Release Data ──────────────────────────────────────────────────────

  function renderReleaseData(container, data) {
    let html = '<div class="component release-data"><div class="component-header"><h3>Release Readiness</h3></div>';

    if (data.blockers?.length) {
      html += `<div class="blockers-section"><h4>Release Blockers</h4>
        ${data.blockers.map(i => issueRow(i)).join('')}</div>`;
    }

    const sections = [
      ['Open Bugs', data.openBugs || data.bugs],
      ['Epics', data.epics],
    ];

    for (const [title, items] of sections) {
      if (items?.length) {
        html += collapsibleSection(title, items.length,
          items.map(i => issueRow(i)).join(''));
      }
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // ── GitHub Components ─────────────────────────────────────────────────

  function prRow(pr) {
    const stateClass = pr.isDraft ? 'draft' : (pr.state || 'open').toLowerCase();
    const stateLabel = pr.isDraft ? 'Draft' : (pr.state || 'OPEN');
    return `<div class="pr-row">
      <span class="pr-state pr-state-${stateClass}">${esc(stateLabel)}</span>
      <a href="${esc(pr.url)}" target="_blank" rel="noopener" class="pr-title">${esc(pr.title)}</a>
      <span class="pr-repo">${esc(pr.repo)}</span>
      ${pr.author ? `<span class="pr-author">${esc(pr.author)}</span>` : ''}
      ${pr.ageDays ? `<span class="pr-age">${pr.ageDays}d</span>` : ''}
    </div>`;
  }

  function renderTeamPRs(container, data) {
    let html = '<div class="component team-prs"><div class="component-header"><h3>Team GitHub Activity</h3></div>';

    for (const member of (data.members || [])) {
      if (member.prs?.length || member.authored) {
        html += `<details class="section-details"><summary>${esc(member.name || member.github)}
          <span class="section-count">(${member.authored || member.prs?.length || 0} PRs)</span></summary>
          <div class="section-body">${(member.prs || []).map(prRow).join('')}</div>
        </details>`;
      }
    }

    html += '</div>';
    container.innerHTML = html;
  }

  function renderMemberPRs(container, data) {
    let html = '<div class="component member-prs"><div class="component-header"><h3>GitHub Activity</h3></div>';

    if (data.authored?.length) {
      html += collapsibleSection('Authored PRs', data.authored.length,
        data.authored.map(prRow).join(''), true);
    }
    if (data.reviewed?.length) {
      html += collapsibleSection('Reviewed', data.reviewed.length,
        data.reviewed.map(prRow).join(''));
    }
    if (data.issues?.length) {
      html += collapsibleSection('Issues', data.issues.length,
        data.issues.map(prRow).join(''));
    }

    html += '</div>';
    container.innerHTML = html;
  }

  function renderMyPRs(container, data) {
    const sum = data.summary || {};
    let html = `<div class="component my-prs"><div class="component-header"><h3>My PRs</h3></div>
      <div class="chip-row">
        ${chip('Open', sum.openPRs, 'inProgress')}
        ${chip('Recently Merged', sum.recentlyMerged, 'done')}
        ${chip('Review Requests', sum.reviewRequests, 'codeReview')}
      </div>`;

    if (data.authoredOpen?.length) {
      html += collapsibleSection('Open PRs', data.authoredOpen.length,
        data.authoredOpen.map(prRow).join(''), true);
    }
    if (data.reviewRequested?.length) {
      html += collapsibleSection('Review Requested', data.reviewRequested.length,
        data.reviewRequested.map(prRow).join(''), true);
    }
    if (data.authoredMerged?.length) {
      html += collapsibleSection('Recently Merged', data.authoredMerged.length,
        data.authoredMerged.map(prRow).join(''));
    }

    html += '</div>';
    container.innerHTML = html;
  }

  function renderMyIssues(container, data) {
    let html = '<div class="component my-issues"><div class="component-header"><h3>My GitHub Issues</h3></div>';

    if (data.authored?.length) {
      html += collapsibleSection('Authored', data.authored.length,
        data.authored.map(prRow).join(''), true);
    }
    if (data.assigned?.length) {
      html += collapsibleSection('Assigned', data.assigned.length,
        data.assigned.map(prRow).join(''));
    }
    if (data.commented?.length) {
      html += collapsibleSection('Commented', data.commented.length,
        data.commented.map(prRow).join(''));
    }

    html += '</div>';
    container.innerHTML = html;
  }

  function renderReviewQueue(container, data) {
    let html = '<div class="component review-queue"><div class="component-header"><h3>Review Queue</h3></div>';

    if (data.reviewRequested?.length) {
      html += data.reviewRequested.map(prRow).join('');
    } else {
      html += '<p class="empty-state">No PRs waiting for your review.</p>';
    }

    if (data.mentioned?.length) {
      html += collapsibleSection('Mentioned', data.mentioned.length,
        data.mentioned.map(prRow).join(''));
    }

    html += '</div>';
    container.innerHTML = html;
  }

  // ── Utility ───────────────────────────────────────────────────────────

  function formatDate(iso) {
    if (!iso) return '';
    try {
      const d = new Date(iso);
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    } catch (_) {
      return iso;
    }
  }
})();
