import { Router } from 'express';
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import { stmts } from '../db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '..', '..');

function sendSSE(res, event, data) {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

// Map bin/jira.sh and bin/gh-activity.sh subcommands to rich component types
const RICH_TYPE_MAP = {
  'sprint-dashboard': 'sprint_dashboard',
  'bug-overview': 'bug_overview',
  'standup-data': 'standup_data',
  'issue-deep-dive': 'issue_deep_dive',
  'carryover-report': 'carryover_report',
  'planning-data': 'planning_data',
  'release-data': 'release_data',
  'epic-progress': 'epic_progress',
  'my-board-data': 'my_board',
  'my-bugs-data': 'my_bugs',
  'pickup-data': 'pickup_data',
  'my-standup-data': 'my_standup',
  'team-prs': 'team_prs',
  'member-prs': 'member_prs',
  'my-prs': 'my_prs',
  'my-issues': 'my_issues',
  'review-queue': 'review_queue',
};

function detectRichCommand(command) {
  if (!command) return null;
  const m = command.match(/(?:bin\/jira\.sh|bin\/gh-activity\.sh)\s+([\w-]+)/);
  return m ? (RICH_TYPE_MAP[m[1]] || null) : null;
}

const SYSTEM_PROMPT = `You are a Scrum Master assistant for the OpenShift Node team at Red Hat. You help manage sprints, triage bugs, prepare standups, and track team workload.

You have full access to tools — use Bash to call bin/jira.sh and bin/gh-activity.sh for Jira and GitHub operations (see CLAUDE.md for full API reference). You also have access to productivity plugins (GitHub, Slack, Google) for broader queries.

IMPORTANT: Do NOT use the Skill tool for project slash commands (standup, sprint-status, sprint-plan, bug-triage, carryovers, team-load, sprint-review, investigate, release-check, my-board, my-bugs, my-epics, my-standup, pickup, team-member, briefing, handoff, update, blocker, review-queue, my-prs, my-github-issues, team-member-github, standup-github, self-improvement). Instead, use Bash to call bin/jira.sh and bin/gh-activity.sh directly. Only use the Skill tool for marketplace plugin skills (github:github, slack:slack, google:google, redhat-detective:*).

Key context:
- Two sub-teams: "Node Devices" (DRA/Instaslice) and "Node Core" (kubelet, CRI-O, etc.)
- Jira projects: OCPNODE (epics/stories/tasks), OCPBUGS (bugs)
- Sprint naming: "OCP Node Core Sprint N", "OCP Node Devices Sprint N"
- Board ID: 7845
- Team rosters: config/team-roster-dra.json (Node Devices), config/team-roster-core.json (Node Core)
- User's GitHub handle: harche
- User's Jira email: harpatil@redhat.com

When Bash tool results return structured JSON from bin/jira.sh or bin/gh-activity.sh, the UI will render them as rich interactive components automatically. Focus your text on analysis, insights, and recommendations rather than re-listing raw data.

For write operations (transitions, comments, setting points), ALWAYS confirm with the user before executing. Draft what you plan to do and ask for confirmation.

Always include clickable Jira links: https://redhat.atlassian.net/browse/{KEY}

Meeting cadence:
- Tuesdays 9:00 AM ET: Node Devices Standup/Grooming
- Wednesdays 8:00 AM ET: Node Core Scrum/Bug Scrub`;

export function createChatRouter() {
  const router = Router();

  router.post('/', async (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    let aborted = false;
    res.on('close', () => {
      aborted = true;
      if (proc && !proc.killed) proc.kill('SIGTERM');
    });

    const { message, conversationId, selectedTeam } = req.body;

    // Look up session_id for multi-turn
    let sessionId = null;
    if (conversationId) {
      const conv = stmts.getConversation.get(conversationId);
      sessionId = conv?.session_id || null;
    }

    // Build claude CLI args
    const args = [
      '-p',
      '--output-format', 'stream-json',
      '--verbose',
      '--include-partial-messages',
      '--model', 'opus',
      '--dangerously-skip-permissions',
      '--append-system-prompt', SYSTEM_PROMPT + (selectedTeam
        ? `\n\nTeam Selection: The user's message starts with [Team: ${selectedTeam}]. This means they already selected "${selectedTeam}" via the UI. The team question is answered — use "${selectedTeam}" for all commands. Do not ask again, do not deliberate, do not consider other teams even if a member is on multiple rosters.`
        : ''),
    ];

    if (sessionId) {
      args.push('--resume', sessionId);
    }

    // Prepend team selection to the message so Claude treats it as user-provided
    const effectiveMessage = selectedTeam
      ? `[Team: ${selectedTeam}]\n\n${message}`
      : message;
    args.push(effectiveMessage);

    const proc = spawn('claude', args, {
      cwd: PROJECT_ROOT,
      env: process.env,
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    // State for streaming translation
    let currentBlock = null;
    let currentInput = '';
    let capturedSessionId = null;
    const pendingBashCalls = new Map(); // tool_use_id → { command, richType }

    function handleStreamEvent(event) {
      if (aborted) return;

      switch (event.type) {
        case 'content_block_start': {
          currentBlock = event.content_block;
          currentInput = '';
          if (currentBlock.type === 'thinking') {
            sendSSE(res, 'thinking_start', {});
          } else if (currentBlock.type === 'tool_use') {
            sendSSE(res, 'tool_start', { name: currentBlock.name, id: currentBlock.id });
          }
          break;
        }

        case 'content_block_delta': {
          const delta = event.delta;
          if (delta.type === 'thinking_delta') {
            sendSSE(res, 'thinking_delta', { text: delta.thinking });
          } else if (delta.type === 'text_delta') {
            sendSSE(res, 'text_delta', { text: delta.text });
          } else if (delta.type === 'input_json_delta') {
            currentInput += delta.partial_json;
          }
          break;
        }

        case 'content_block_stop': {
          if (currentBlock) {
            if (currentBlock.type === 'thinking') {
              sendSSE(res, 'thinking_end', {});
            } else if (currentBlock.type === 'tool_use') {
              let parsedInput = {};
              try { parsedInput = JSON.parse(currentInput); } catch (_) {}
              // For Skill tool, use the skill name as the display name
              const displayName = currentBlock.name === 'Skill' && parsedInput.skill
                ? parsedInput.skill
                : currentBlock.name;
              sendSSE(res, 'tool_call', {
                id: currentBlock.id,
                name: displayName,
                input: parsedInput,
              });
              // Handle AskUserQuestion — emit user_prompt for the frontend prompt card
              if (currentBlock.name === 'AskUserQuestion') {
                const questions = parsedInput.questions || [];
                if (questions.length > 0) {
                  for (const q of questions) {
                    const options = (q.options || []).map(o =>
                      typeof o === 'string' ? o : (o.label || o.value || String(o))
                    );
                    sendSSE(res, 'user_prompt', {
                      question: q.question || q.header || 'Please choose:',
                      context: q.header || undefined,
                      options,
                    });
                  }
                } else if (parsedInput.question) {
                  const options = (parsedInput.options || []).map(o =>
                    typeof o === 'string' ? o : (o.label || o.value || String(o))
                  );
                  sendSSE(res, 'user_prompt', {
                    question: parsedInput.question,
                    options,
                  });
                }
              }
              // Track Bash calls for rich data detection
              if (currentBlock.name === 'Bash' && parsedInput.command) {
                const richType = detectRichCommand(parsedInput.command);
                if (richType) {
                  pendingBashCalls.set(currentBlock.id, {
                    command: parsedInput.command,
                    richType,
                  });
                }
              }
            }
          }
          currentBlock = null;
          currentInput = '';
          break;
        }

        case 'message_delta': {
          // stop_reason tracked by the result message
          break;
        }
      }
    }

    function handleToolResult(msg) {
      if (aborted) return;
      const content = msg.message?.content || [];
      for (const item of content) {
        if (item.type !== 'tool_result') continue;

        const toolUseId = item.tool_use_id;
        const isError = item.is_error || false;
        const resultText = typeof item.content === 'string'
          ? item.content
          : JSON.stringify(item.content);

        sendSSE(res, 'tool_result', {
          tool_use_id: toolUseId,
          content: [{ type: 'text', text: resultText }],
          isError,
        });

        // Check for rich data from tracked Bash calls
        if (!isError && pendingBashCalls.has(toolUseId)) {
          const { richType } = pendingBashCalls.get(toolUseId);
          // Use stdout from tool_use_result if available, else content
          const rawOutput = msg.tool_use_result?.stdout || resultText;
          try {
            const jsonData = JSON.parse(rawOutput);
            sendSSE(res, 'rich_data', {
              type: richType,
              toolUseId,
              toolName: richType,
              data: jsonData,
            });
          } catch (_) {
            // Not valid JSON — skip rich rendering
          }
          pendingBashCalls.delete(toolUseId);
        }
      }
    }

    function handleMessage(msg) {
      if (aborted) return;

      switch (msg.type) {
        case 'system':
          if (msg.subtype === 'init' && msg.session_id) {
            capturedSessionId = msg.session_id;
          }
          break;

        case 'stream_event':
          handleStreamEvent(msg.event);
          break;

        case 'user':
          // Tool results from the CLI executing tools
          handleToolResult(msg);
          break;

        case 'result':
          capturedSessionId = msg.session_id || capturedSessionId;
          sendSSE(res, 'done', { stop_reason: msg.stop_reason || 'end_turn' });
          break;

        // 'assistant' — complete messages, already streamed via stream_events
      }
    }

    // Parse stdout line by line
    let buffer = '';

    proc.stdout.on('data', (chunk) => {
      if (aborted) return;
      buffer += chunk.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop(); // keep incomplete last line

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          handleMessage(JSON.parse(line));
        } catch (_) {
          // malformed JSON line — skip
        }
      }
    });

    proc.stderr.on('data', (chunk) => {
      const text = chunk.toString().trim();
      if (text) console.error(`[claude stderr] ${text}`);
    });

    proc.on('close', (code) => {
      // Process remaining buffer
      if (buffer.trim()) {
        try {
          handleMessage(JSON.parse(buffer));
        } catch (_) {}
      }

      // Save session_id for multi-turn
      if (capturedSessionId && conversationId) {
        try {
          stmts.updateSessionId.run(capturedSessionId, conversationId);
        } catch (err) {
          console.error('[session save error]', err.message);
        }
      }

      if (code !== 0 && !aborted) {
        sendSSE(res, 'error', { message: `Claude process exited with code ${code}` });
      }

      if (!aborted) res.end();
    });

    proc.on('error', (err) => {
      console.error('[claude spawn error]', err);
      if (!aborted) {
        sendSSE(res, 'error', { message: `Failed to start Claude: ${err.message}` });
        res.end();
      }
    });
  });

  return router;
}
