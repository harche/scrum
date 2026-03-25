import express from 'express';
import { fileURLToPath } from 'url';
import path from 'path';
import { createProvider } from './provider.js';
import { createChatRouter } from './routes/chat.js';
import { createConversationsRouter } from './routes/conversations.js';
import { stmts } from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
const aiProvider = await createProvider();

app.use(express.json({ limit: '10mb' }));
app.use(express.static(path.join(__dirname, '..', 'public')));

app.use('/api/chat', createChatRouter(aiProvider));
app.use('/api/conversations', createConversationsRouter(stmts));

const PORT = process.env.PORT || 4001;
app.listen(PORT, () => {
  console.log(`Scrum Dashboard running on http://localhost:${PORT}`);
});
