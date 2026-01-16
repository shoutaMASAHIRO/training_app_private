const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const app = express();
const PORT = Number(process.env.PORT || 3000);

app.use(cors());
app.use(express.json());
app.use((req, _res, next) => {
  console.log(`[REQ] ${req.method} ${req.url}`);
  next();
});

// PostgreSQL Pool Configuration
const pool = new Pool({
  user: process.env.DB_USER || 'user',
  host: process.env.DB_HOST || 'postgres',
  database: process.env.DB_NAME || 'fitness_db',
  password: process.env.DB_PASSWORD || 'password',
  port: Number(process.env.DB_PORT || 5432),
});

// ✅ DB が ready になるまで待つ（ECONNREFUSED対策）
async function waitForDb(retries = 60, delayMs = 1000) {
  for (let i = 1; i <= retries; i++) {
    try {
      await pool.query('SELECT 1');
      console.log('DB is ready.');
      return;
    } catch (err) {
      console.log(`DB not ready (${i}/${retries}) -> ${err.code || err.message}`);
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
  throw new Error('DB did not become ready in time');
}

// users table
async function createTable() {
  const createTableQuery = `
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(255) UNIQUE NOT NULL,
      password VARCHAR(255) NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `;
  await pool.query(createTableQuery);
  console.log("Table 'users' is ready.");
}

// health endpoint
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    return res.status(200).json({ ok: true });
  } catch (err) {
    return res.status(500).json({ ok: false, error: err.code || err.message });
  }
});

// Register
app.post('/register', async (req, res) => {
  const { username, password } = req.body || {};

  if (!username || !password) {
    return res.status(400).json({ message: 'Username and password are required' });
  }

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const insertUserQuery =
      'INSERT INTO users (username, password) VALUES ($1, $2) RETURNING id;';

    await pool.query(insertUserQuery, [username, hashedPassword]);

    return res.status(201).json({ message: 'User registered successfully' });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ message: 'Username already exists' });
    }
    console.error('Error registering user:', err);
    return res.status(500).json({ message: 'Error registering user' });
  }
});

// Login
app.post('/login', async (req, res) => {
  const { username, password } = req.body || {};

  if (!username || !password) {
    return res.status(400).json({ message: 'Username and password are required' });
  }

  const findUserQuery = 'SELECT * FROM users WHERE username = $1;';

  try {
    const { rows } = await pool.query(findUserQuery, [username]);
    const user = rows[0];

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    return res.status(200).json({ message: 'Login successful' });
  } catch (err) {
    console.error('Error logging in user:', err);
    return res.status(500).json({ message: 'Error logging in user' });
  }
});

app.get('/', (req, res) => {
  res.send('Backend server is running!');
});

async function startServer() {
  try {
    await waitForDb();
    await createTable();

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server is running on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('Startup failed:', err);
    process.exit(1);
  }
}

startServer();

// graceful shutdown
async function shutdown() {
  try {
    console.log('Shutting down...');
    await pool.end();
  } finally {
    process.exit(0);
  }
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
