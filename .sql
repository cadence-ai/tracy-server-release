PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

CREATE TABLE IF NOT EXISTS roles (
    id   INTEGER PRIMARY KEY NOT NULL,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS agents (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT UNIQUE NOT NULL,
    role          TEXT NOT NULL,
    folder        TEXT,
    model         TEXT NOT NULL,
    embedding_model TEXT,
    format        TEXT,
    created_at    INTEGER NOT NULL DEFAULT (unixepoch())
    );

CREATE TABLE IF NOT EXISTS conversations (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id   INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),

    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
    );

CREATE TABLE IF NOT EXISTS messages (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id INTEGER NOT NULL,
    role_id         INTEGER NOT NULL,
    content         TEXT NOT NULL,
    created_at      INTEGER NOT NULL DEFAULT (unixepoch()),

    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id)         REFERENCES roles(id)         ON DELETE CASCADE
    );

INSERT OR IGNORE INTO roles (id, name) VALUES (1, 'system');
INSERT OR IGNORE INTO roles (id, name) VALUES (2, 'user');
INSERT OR IGNORE INTO roles (id, name) VALUES (3, 'assistant');