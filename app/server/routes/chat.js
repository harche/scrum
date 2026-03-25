import { Router } from 'express';
import { TOOLS } from '../tools.js';
import { executeTool, detectRichType } from '../executor.js';

function sendSSE(res, event, data) {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

async function consumeStream(stream, res, isAborted) {
  const contentBlocks = [];
  let currentBlock = null;
  let stopReason = null;
  let thinkingText = '';
  let signatureText = '';
  let currentText = '';
  let currentInput = '';

  for await (const event of stream) {
    if (isAborted()) {
      stream.controller?.abort();
      break;
    }
    switch (event.type) {
      case 'content_block_start': {
        currentBlock = event.content_block;
        thinkingText = '';
        signatureText = '';
        currentText = '';
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
          thinkingText += delta.thinking;
          sendSSE(res, 'thinking_delta', { text: delta.thinking });
        } else if (delta.type === 'signature_delta') {
          signatureText += delta.signature;
        } else if (delta.type === 'text_delta') {
          currentText += delta.text;
          sendSSE(res, 'text_delta', { text: delta.text });
        } else if (delta.type === 'input_json_delta') {
          currentInput += delta.partial_json;
        }
        break;
      }

      case 'content_block_stop': {
        if (currentBlock) {
          if (currentBlock.type === 'thinking') {
            contentBlocks.push({
              type: 'thinking',
              thinking: thinkingText,
              signature: signatureText,
            });
            sendSSE(res, 'thinking_end', {});
          } else if (currentBlock.type === 'text') {
            contentBlocks.push({ ...currentBlock, text: currentText });
          } else if (currentBlock.type === 'tool_use') {
            let parsedInput = {};
            try { parsedInput = JSON.parse(currentInput); } catch (_) {}
            const block = { ...currentBlock, input: parsedInput };
            contentBlocks.push(block);
            sendSSE(res, 'tool_call', {
              id: block.id,
              name: block.name,
              input: block.input,
            });
          } else {
            contentBlocks.push(currentBlock);
          }
        }
        currentBlock = null;
        break;
      }

      case 'message_delta': {
        stopReason = event.delta?.stop_reason || stopReason;
        break;
      }
    }
  }

  return { content: contentBlocks, stop_reason: stopReason };
}

const SYSTEM_PROMPT = `You are a Scrum Master assistant for the OpenShift Node team at Red Hat. You help manage sprints, triage bugs, prepare standups, and track team workload.

You have access to tools that call Jira and GitHub APIs. Use them to answer questions about sprint status, bugs, team activity, and more.

Key context:
- Two sub-teams: "Node Devices" (DRA/Instaslice) and "Node Core" (kubelet, CRI-O, etc.)
- Jira projects: OCPNODE (epics/stories/tasks), OCPBUGS (bugs)
- Sprint naming: "OCP Node Core Sprint N", "OCP Node Devices Sprint N"
- Board ID: 7845
- Team rosters: config/team-roster-dra.json (Node Devices), config/team-roster-core.json (Node Core)
- User's GitHub handle: harche
- User's Jira email: harpatil@redhat.com

When tool results return structured JSON, the UI will render them as rich interactive components automatically. Focus your text on analysis, insights, and recommendations rather than re-listing the data.

For write operations (transitions, comments, setting points), ALWAYS confirm with the user before executing. Draft what you plan to do and ask for confirmation.

Always include clickable Jira links: https://redhat.atlassian.net/browse/{KEY}

Meeting cadence:
- Tuesdays 9:00 AM ET: Node Devices Standup/Grooming
- Wednesdays 8:00 AM ET: Node Core Scrum/Bug Scrub`;

export function createChatRouter(aiProvider) {
  const router = Router();

  router.post('/', async (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    let aborted = false;
    res.on('close', () => { aborted = true; });

    const { messages, system } = req.body;
    const conversationMessages = messages.map(m => ({ ...m }));
    const systemPrompt = system || SYSTEM_PROMPT;

    let iterations = 0;
    const MAX_ITERATIONS = 10;

    try {
      while (iterations < MAX_ITERATIONS && !aborted) {
        iterations++;

        const stream = await aiProvider.streamMessage(
          conversationMessages, TOOLS, systemPrompt
        );

        const response = await consumeStream(stream, res, () => aborted);

        if (response.stop_reason === 'end_turn' || response.stop_reason === 'max_tokens') {
          sendSSE(res, 'done', { stop_reason: response.stop_reason });
          break;
        }

        const toolUseBlocks = response.content.filter(b => b.type === 'tool_use');
        if (toolUseBlocks.length === 0) {
          sendSSE(res, 'done', { stop_reason: response.stop_reason });
          break;
        }

        conversationMessages.push({ role: 'assistant', content: response.content });

        if (aborted) break;

        const toolResults = [];
        for (const toolUse of toolUseBlocks) {
          if (aborted) break;

          let result;
          try {
            result = await executeTool(toolUse.name, toolUse.input);
          } catch (err) {
            result = {
              content: [{ type: 'text', text: `Error: ${err.message}` }],
              isError: true,
            };
          }

          sendSSE(res, 'tool_result', {
            tool_use_id: toolUse.id,
            content: result.content,
            isError: result.isError || false,
          });

          // Check if the result is rich-renderable JSON
          if (!result.isError) {
            const richType = detectRichType(toolUse.name);
            if (richType) {
              try {
                const jsonData = JSON.parse(result.content[0].text);
                sendSSE(res, 'rich_data', {
                  type: richType,
                  toolUseId: toolUse.id,
                  toolName: toolUse.name,
                  data: jsonData,
                });
              } catch (_) {
                // Not valid JSON — skip rich rendering
              }
            }
          }

          const resultContent = result.content?.map(c => {
            if (c.type === 'text') return { type: 'text', text: c.text };
            return { type: 'text', text: JSON.stringify(c) };
          }) || [{ type: 'text', text: 'No output' }];

          toolResults.push({
            type: 'tool_result',
            tool_use_id: toolUse.id,
            content: resultContent,
            is_error: result.isError || false,
          });
        }

        conversationMessages.push({ role: 'user', content: toolResults });
      }

      if (iterations >= MAX_ITERATIONS) {
        sendSSE(res, 'error', { message: 'Maximum tool use iterations reached' });
      }
    } catch (error) {
      console.error('Chat error:', error);
      sendSSE(res, 'error', { message: error.message || 'Unknown error' });
    }

    if (!aborted) res.end();
  });

  return router;
}
