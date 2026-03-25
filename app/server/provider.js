class ChatProvider {
  constructor(client, model, maxTokens) {
    this.client = client;
    this.model = model;
    this.maxTokens = maxTokens;
  }

  async streamMessage(messages, tools = [], systemPrompt = '') {
    const params = {
      model: this.model,
      max_tokens: this.maxTokens,
      messages,
      thinking: {
        type: 'enabled',
        budget_tokens: 4096,
      },
      stream: true,
    };
    if (tools.length > 0) params.tools = tools;
    if (systemPrompt) params.system = systemPrompt;

    return this.client.messages.create(params);
  }
}

function detectProvider() {
  if (process.env.VERTEX_PROJECT_ID || process.env.ANTHROPIC_VERTEX_PROJECT_ID) return 'vertex';
  if (process.env.ANTHROPIC_API_KEY) return 'anthropic';
  throw new Error(
    'No AI provider credentials found. Set VERTEX_PROJECT_ID (or ANTHROPIC_VERTEX_PROJECT_ID), or ANTHROPIC_API_KEY'
  );
}

export async function createProvider() {
  const provider = detectProvider();
  const maxTokens = parseInt(process.env.MAX_TOKENS, 10) || 16384;
  const model = process.env.MODEL_ID || 'claude-opus-4-6';

  if (provider === 'vertex') {
    const projectId = process.env.VERTEX_PROJECT_ID || process.env.ANTHROPIC_VERTEX_PROJECT_ID;
    const { AnthropicVertex } = await import('@anthropic-ai/vertex-sdk');
    const client = new AnthropicVertex({
      projectId,
      region: process.env.VERTEX_REGION || 'us-east5',
    });
    return new ChatProvider(client, model, maxTokens);
  }

  // Direct Anthropic API
  const { default: Anthropic } = await import('@anthropic-ai/sdk');
  const client = new Anthropic();
  return new ChatProvider(client, model, maxTokens);
}
