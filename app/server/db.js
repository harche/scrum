import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export function initDb(dbPath) {
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');

  db.exec(`
    CREATE TABLE IF NOT EXISTS conversations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      session_id TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
    );
  `);

  // Migration: add session_id column if missing (existing databases)
  try {
    db.exec('ALTER TABLE conversations ADD COLUMN session_id TEXT');
  } catch (_) {
    // Column already exists
  }

  const stmts = {
    listConversations: db.prepare(
      'SELECT id, title, created_at, updated_at FROM conversations ORDER BY updated_at DESC'
    ),
    createConversation: db.prepare(
      'INSERT INTO conversations (title) VALUES (?)'
    ),
    getConversation: db.prepare(
      'SELECT id, title, session_id, created_at, updated_at FROM conversations WHERE id = ?'
    ),
    updateConversation: db.prepare(
      'UPDATE conversations SET title = ?, updated_at = datetime(\'now\') WHERE id = ?'
    ),
    touchConversation: db.prepare(
      'UPDATE conversations SET updated_at = datetime(\'now\') WHERE id = ?'
    ),
    deleteConversation: db.prepare(
      'DELETE FROM conversations WHERE id = ?'
    ),
    getMessages: db.prepare(
      'SELECT id, role, content, created_at FROM messages WHERE conversation_id = ? ORDER BY created_at ASC'
    ),
    addMessage: db.prepare(
      'INSERT INTO messages (conversation_id, role, content) VALUES (?, ?, ?)'
    ),
    updateSessionId: db.prepare(
      'UPDATE conversations SET session_id = ? WHERE id = ?'
    ),
  };

  return { db, stmts };
}

const defaultPath = path.join(__dirname, 'scrum-dashboard.db');
const { db, stmts } = initDb(defaultPath);

export { stmts };
export default db;
