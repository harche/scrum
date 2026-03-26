// Main chat application
(function() {
  const messagesEl = document.getElementById('messages');
  const chatForm = document.getElementById('chat-form');
  const userInput = document.getElementById('user-input');
  const sendBtn = document.getElementById('send-btn');
  const stopBtn = document.getElementById('stop-btn');
  const teamSelector = document.getElementById('team-selector');

  let conversationHistory = [];
  let activeStreams = 0;
  const activeControllers = new Set();

  const cardDataStore = new Map();

  function streamStarted(controller) {
    activeStreams++;
    activeControllers.add(controller);
    sendBtn.classList.add('hidden');
    stopBtn.classList.remove('hidden');
  }

  function streamEnded(controller) {
    activeControllers.delete(controller);
    activeStreams = Math.max(0, activeStreams - 1);
    if (activeStreams === 0) {
      stopBtn.classList.add('hidden');
      sendBtn.classList.remove('hidden');
      userInput.focus();
    }
  }

  // Shared escape function — also used by components.js via window
  window._escapeHtml = function(text) {
    const div = document.createElement('div');
    div.textContent = text || '';
    return div.innerHTML;
  };

  // Debounced scroll: only scroll if user is near the bottom
  let userScrolledUp = false;
  let scrollRafId = null;
  messagesEl.addEventListener('scroll', () => {
    const distFromBottom = messagesEl.scrollHeight - messagesEl.scrollTop - messagesEl.clientHeight;
    userScrolledUp = distFromBottom > 20;
  });

  function scrollToBottom() {
    if (userScrolledUp) return;
    if (scrollRafId) return; // already scheduled
    scrollRafId = requestAnimationFrame(() => {
      messagesEl.scrollTop = messagesEl.scrollHeight;
      scrollRafId = null;
    });
  }

  // Debounced markdown rendering during streaming
  let renderTimer = null;
  let pendingRenderEl = null;
  let pendingRenderText = '';

  function scheduleRender(el, text) {
    pendingRenderEl = el;
    pendingRenderText = text;
    if (!renderTimer) {
      renderTimer = setTimeout(flushRender, 80);
    }
  }

  function flushRender() {
    renderTimer = null;
    if (pendingRenderEl) {
      pendingRenderEl.innerHTML = renderMarkdown(pendingRenderText);
      scrollToBottom();
      pendingRenderEl = null;
    }
  }

  if (window.chatHistory) {
    window.chatHistory.onConversationLoad = (messages) => {
      conversationHistory = messages;
      renderAllMessages(messages);
    };
    window.chatHistory.onNewChat = () => {
      conversationHistory = [];
      showWelcome();
    };
  }

  function showWelcome() {
    messagesEl.innerHTML = `<div class="welcome">
      <h2>Scrum Master Dashboard</h2>
      <p>Chat with your scrum assistant or search commands above.</p>
      <p class="welcome-hint">Press <kbd>/</kbd> or <kbd>Cmd+K</kbd> to search commands, or just type in the chat.</p>
    </div>`;
  }

  function renderAllMessages(messages) {
    messagesEl.innerHTML = '';
    for (const msg of messages) {
      if (msg.role === 'user') {
        renderUserMessage(typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content));
      } else if (msg.role === 'assistant') {
        const div = document.createElement('div');
        div.className = 'message assistant';
        const content = document.createElement('div');
        content.className = 'content';
        const textEl = document.createElement('div');
        textEl.className = 'text-content';
        textEl.innerHTML = renderMarkdown(typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content));
        content.appendChild(textEl);
        div.appendChild(content);
        messagesEl.appendChild(div);
      }
    }
    scrollToBottom();
  }

  // Allow clicking links even while streaming — fires a parallel request
  window.sendChatMessage = function(text) {
    // User clicked something intentionally — re-enable auto-scroll so they see the result
    userScrolledUp = false;
    submitUserMessage(text);
  };

  window.dismissCard = function(cardId) {
    const card = document.getElementById(cardId);
    if (!card) return;
    const meta = cardDataStore.get(cardId);
    if (meta?.toolUseId) {
      for (const msg of conversationHistory) {
        if (msg.role === 'user' && Array.isArray(msg.content)) {
          for (const block of msg.content) {
            if (block.type === 'tool_result' && block.tool_use_id === meta.toolUseId) {
              block.content = [{ type: 'text', text: `[${meta.toolName} data dismissed by user]` }];
            }
          }
        }
      }
      const toolEl = document.getElementById(`tool-${meta.toolUseId}`);
      if (toolEl) toolEl.remove();
    }
    cardDataStore.delete(cardId);
    card.remove();
  };

  window.forkFromCard = function(cardId) {
    const meta = cardDataStore.get(cardId);
    if (!meta?.rawData) return;

    const { toolName, richType, rawData } = meta;
    let data;
    try { data = JSON.parse(rawData); } catch (_) { return; }

    let label = toolName;
    if (data.sprint) label = data.sprint.name;
    else if (data.key) label = `${data.key} - ${data.summary}`;
    else if (data.summary?.totalOpen !== undefined) label = `Bug triage (${data.summary.totalOpen} open)`;

    if (window.chatHistory) {
      window.chatHistory.startNewChat();
    } else {
      conversationHistory = [];
    }

    conversationHistory = [
      { role: 'user', content: `I want to discuss this ${toolName} data:\n${rawData}` },
      { role: 'assistant', content: `I have the ${label} data. What would you like to do?` },
    ];

    messagesEl.innerHTML = '';
    renderUserMessage(`Forked: ${label}`);

    const assistDiv = document.createElement('div');
    assistDiv.className = 'message assistant';
    const contentDiv = document.createElement('div');
    contentDiv.className = 'content';

    const newCardId = `card-fork-${Date.now()}`;
    const newCard = document.createElement('div');
    newCard.className = 'rich-component';
    newCard.id = newCardId;
    cardDataStore.set(newCardId, { toolName, richType, rawData });
    window.renderComponent(newCard, richType, data);
    addCardToolbar(newCard, newCardId);
    contentDiv.appendChild(newCard);

    const promptEl = document.createElement('div');
    promptEl.className = 'text-content';
    promptEl.innerHTML = renderMarkdown(`What would you like to do with this **${label}** data?`);
    contentDiv.appendChild(promptEl);

    assistDiv.appendChild(contentDiv);
    messagesEl.appendChild(assistDiv);
    scrollToBottom();

    if (window.chatHistory) {
      window.chatHistory.ensureConversation(`Fork: ${label}`).then(() => {
        window.chatHistory.saveMessage('user', `Forked: ${label}`);
        window.chatHistory.saveMessage('assistant', `I have the ${label} data. What would you like to do?`);
      });
    }
    userInput.focus();
  };

  function addCardToolbar(container, cardId, showFork = true) {
    const toolbar = document.createElement('div');
    toolbar.className = 'card-toolbar';
    const forkBtn = document.createElement('button');
    forkBtn.className = 'card-tool-btn card-tool-fork';
    forkBtn.title = 'Fork into new chat';
    forkBtn.innerHTML = '&#9095;';
    forkBtn.addEventListener('click', (e) => { e.stopPropagation(); window.forkFromCard(cardId); });
    if (!showFork) forkBtn.style.display = 'none';
    const dismissBtn = document.createElement('button');
    dismissBtn.className = 'card-tool-btn card-tool-dismiss';
    dismissBtn.title = 'Dismiss card';
    dismissBtn.innerHTML = '&times;';
    dismissBtn.addEventListener('click', (e) => { e.stopPropagation(); window.dismissCard(cardId); });
    toolbar.appendChild(forkBtn);
    toolbar.appendChild(dismissBtn);
    container.insertBefore(toolbar, container.firstChild);
  }

  async function submitUserMessage(text) {
    const welcome = messagesEl.querySelector('.welcome');
    if (welcome) welcome.remove();

    conversationHistory.push({ role: 'user', content: text });
    renderUserMessage(text);
    scrollToBottom();

    if (window.chatHistory) {
      await window.chatHistory.ensureConversation(text);
      await window.chatHistory.saveMessage('user', text);
    }

    // Fire and forget — don't block so parallel requests can start
    sendMessage();
  }

  chatForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const text = userInput.value.trim();
    if (!text) return;

    userInput.value = '';
    await submitUserMessage(text);
  });

  userInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      chatForm.dispatchEvent(new Event('submit'));
    }
  });

  function renderUserMessage(text) {
    const div = document.createElement('div');
    div.className = 'message user';
    div.textContent = text;
    messagesEl.appendChild(div);
  }

  function createAssistantMessage() {
    const div = document.createElement('div');
    div.className = 'message assistant';
    const content = document.createElement('div');
    content.className = 'content';
    div.appendChild(content);
    messagesEl.appendChild(div);
    return content;
  }

  stopBtn.addEventListener('click', () => {
    for (const c of activeControllers) c.abort();
  });

  async function sendMessage() {
    const controller = new AbortController();
    streamStarted(controller);

    const contentEl = createAssistantMessage();

    const thinking = document.createElement('div');
    thinking.className = 'thinking-indicator';
    thinking.innerHTML = '<span class="thinking-icon">&#9679;</span> Thinking...';
    contentEl.appendChild(thinking);
    scrollToBottom();

    let currentSegmentText = '';
    let currentTextEl = null;
    let allText = '';
    let hadToolCall = false;
    let hadRichData = false;
    let hadError = false;
    const pendingForkBtns = [];
    let thinkingRemoved = false;

    function removeThinking() {
      if (!thinkingRemoved) {
        try { thinking.remove(); } catch (_) {}
        thinkingRemoved = true;
      }
    }

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: conversationHistory,
          system: '',
        }),
        signal: controller.signal,
      });

      if (!response.ok) {
        removeThinking();
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let eventType = null;
      const esc = window._escapeHtml;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop();

        for (const line of lines) {
          if (line.startsWith('event: ')) {
            eventType = line.slice(7);
          } else if (line.startsWith('data: ') && eventType) {
            removeThinking();

            let data;
            try { data = JSON.parse(line.slice(6)); } catch (_) { continue; }

            switch (eventType) {
              case 'thinking_start': {
                const thinkEl = document.createElement('details');
                thinkEl.className = 'thinking-block';
                thinkEl.setAttribute('open', '');
                thinkEl.innerHTML = `<summary>Thinking...</summary><div class="thinking-text"></div>`;
                contentEl.appendChild(thinkEl);
                scrollToBottom();
                break;
              }

              case 'thinking_delta': {
                const thinkBlock = contentEl.querySelector('.thinking-block:last-of-type .thinking-text');
                if (thinkBlock) {
                  thinkBlock.textContent += data.text;
                  scrollToBottom();
                }
                break;
              }

              case 'thinking_end': {
                const thinkBlock = contentEl.querySelector('.thinking-block:last-of-type');
                if (thinkBlock) {
                  thinkBlock.removeAttribute('open');
                  thinkBlock.querySelector('summary').textContent = 'Thinking';
                }
                break;
              }

              case 'tool_start': {
                const indicator = document.createElement('div');
                indicator.className = 'thinking-indicator';
                indicator.id = `toolstart-${data.id}`;
                indicator.innerHTML = `<span class="thinking-icon">&#9679;</span> Preparing <strong>${esc(data.name)}</strong>...`;
                contentEl.appendChild(indicator);
                scrollToBottom();
                break;
              }

              case 'text_delta': {
                if (hadToolCall || hadRichData) {
                  currentTextEl = null;
                  currentSegmentText = '';
                  hadToolCall = false;
                  hadRichData = false;
                }
                if (!currentTextEl) {
                  currentTextEl = document.createElement('div');
                  currentTextEl.className = 'text-content';
                  contentEl.appendChild(currentTextEl);
                }
                currentSegmentText += data.text;
                allText += data.text;
                scheduleRender(currentTextEl, currentSegmentText);
                break;
              }

              case 'tool_call': {
                hadToolCall = true;
                hadRichData = false;

                const startIndicator = document.getElementById(`toolstart-${data.id}`);
                if (startIndicator) startIndicator.remove();

                const thinkingTool = document.createElement('div');
                thinkingTool.className = 'thinking-indicator';
                thinkingTool.innerHTML = `<span class="thinking-icon">&#9679;</span> Running <strong>${esc(data.name)}</strong>...`;
                thinkingTool.id = `thinking-${data.id}`;
                contentEl.appendChild(thinkingTool);

                const toolEl = document.createElement('div');
                toolEl.className = 'tool-call';
                toolEl.id = `tool-${data.id}`;
                const header = document.createElement('div');
                header.className = 'tool-call-header';
                header.innerHTML = `<span class="icon">&#9654;</span><span class="name">${esc(data.name)}</span><span class="status running">running...</span>`;
                header.addEventListener('click', () => header.nextElementSibling.classList.toggle('expanded'));
                const body = document.createElement('div');
                body.className = 'tool-call-body';
                body.innerHTML = `<div class="section"><div class="label">Input</div><pre>${esc(JSON.stringify(data.input, null, 2))}</pre></div><div class="result-section"></div>`;
                toolEl.appendChild(header);
                toolEl.appendChild(body);
                contentEl.appendChild(toolEl);
                scrollToBottom();
                break;
              }

              case 'tool_result': {
                const thinkingEl = document.getElementById(`thinking-${data.tool_use_id}`);
                if (thinkingEl) thinkingEl.remove();

                const toolEl = document.getElementById(`tool-${data.tool_use_id}`);
                if (!toolEl) break;

                const statusEl = toolEl.querySelector('.status');
                statusEl.className = `status ${data.isError ? 'error' : 'done'}`;
                statusEl.textContent = data.isError ? 'error' : 'done';

                const resultSection = toolEl.querySelector('.result-section');
                const resultText = data.content?.map(c => c.text || JSON.stringify(c)).join('\n') || 'No output';
                resultSection.innerHTML = `<div class="label">Result</div><pre>${esc(truncate(resultText, 2000))}</pre>`;
                scrollToBottom();
                break;
              }

              case 'rich_data': {
                hadRichData = true;
                if (window.renderComponent) {
                  const cardId = `card-${data.toolUseId || Date.now()}`;
                  const container = document.createElement('div');
                  container.className = 'rich-component';
                  container.id = cardId;
                  const rawJson = JSON.stringify(data.data);
                  cardDataStore.set(cardId, {
                    toolUseId: data.toolUseId || '',
                    toolName: data.toolName || '',
                    richType: data.type || '',
                    rawData: rawJson.length < 50000 ? rawJson : null,
                  });
                  window.renderComponent(container, data.type, data.data);
                  addCardToolbar(container, cardId, false);
                  pendingForkBtns.push(container.querySelector('.card-tool-fork'));
                  contentEl.appendChild(container);
                  scrollToBottom();
                }
                break;
              }

              case 'error': {
                hadError = true;
                const errEl = document.createElement('div');
                errEl.className = 'error-message';
                errEl.textContent = `Error: ${data.message}`;
                contentEl.appendChild(errEl);
                scrollToBottom();
                break;
              }

              case 'done':
                break;
            }

            eventType = null;
          }
        }
      }

      flushRender();
      removeThinking();
      // Stream complete — reveal fork buttons on cards
      for (const btn of pendingForkBtns) if (btn) btn.style.display = '';

      if (allText) {
        conversationHistory.push({ role: 'assistant', content: allText });
        if (window.chatHistory) {
          await window.chatHistory.saveMessage('assistant', allText);
          await window.chatHistory.refreshList();
        }
      }

      if (!allText && !hadToolCall && !hadRichData && !hadError) {
        contentEl.parentElement.remove();
      }

    } catch (error) {
      flushRender();
      removeThinking();
      for (const btn of pendingForkBtns) if (btn) btn.style.display = '';
      if (error.name === 'AbortError') {
        const notice = document.createElement('div');
        notice.className = 'interrupted-notice';
        notice.textContent = 'Message interrupted by user';
        const msgDiv = contentEl.parentElement;
        if (!allText && !hadToolCall) {
          msgDiv.replaceWith(notice);
        } else {
          contentEl.appendChild(notice);
        }
      } else {
        hadError = true;
        const errEl = document.createElement('div');
        errEl.className = 'error-message';
        errEl.textContent = `Error: ${error.message}`;
        contentEl.appendChild(errEl);
      }
    } finally {
      streamEnded(controller);
    }
  }

  function truncate(str, maxLen) {
    if (str.length <= maxLen) return str;
    return str.slice(0, maxLen) + '\n... (truncated)';
  }
})();
