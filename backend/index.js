const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const app = express();
const PORT = Number(process.env.PORT || 3000); // ✅ 3000 -> 3001

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

// tables
async function createTables() {
  const queries = [
    `
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(255) UNIQUE NOT NULL,
      password VARCHAR(255) NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    `,
    `
    CREATE TABLE IF NOT EXISTS menus (
        id SERIAL PRIMARY KEY,
        creator_id INTEGER REFERENCES users(id),
        title VARCHAR(255) NOT NULL,
        concept TEXT,
        difficulty VARCHAR(50),
        is_template BOOLEAN DEFAULT false,
        is_public BOOLEAN DEFAULT false
    );
    `,
    `
    CREATE TABLE IF NOT EXISTS workout_schedules (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id),
        menu_id INTEGER NOT NULL REFERENCES menus(id),
        scheduled_date DATE NOT NULL,
        is_completed BOOLEAN DEFAULT false
    );
    `,
    `
    CREATE TABLE IF NOT EXISTS token_types (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL,
        default_amount INTEGER NOT NULL
    );
    `,
    `
    CREATE TABLE IF NOT EXISTS token_logs (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id),
        token_type_id INTEGER NOT NULL REFERENCES token_types(id),
        amount INTEGER NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    `,
  ];
  for (const query of queries) {
    await pool.query(query);
  }
  console.log("All tables are ready.");
}

// seed mock data
async function seedData() {
  const { rowCount: userCo } = await pool.query('SELECT id FROM users WHERE id = 1');
  if (userCo === 0) {
    const hashed = await bcrypt.hash('password', 10);
    await pool.query('INSERT INTO users(id, username, password) VALUES ($1, $2, $3)', [1, 'user1', hashed]);
    console.log('Mock user "user1" created.');
  }

  const { rowCount: menuCo } = await pool.query('SELECT id FROM menus');
  if (menuCo === 0) {
    await pool.query(
      `INSERT INTO menus(id, creator_id, title, concept, difficulty, is_template, is_public) VALUES
        (1, 1, 'Full Body Workout', 'A balanced workout for the whole body.', 'Intermediate', true, true),
        (2, 1, 'Leg Day Special', 'Intensive leg training.', 'Advanced', false, true);`
    );
    console.log('Mock menus created.');
  }

  const { rowCount: scheduleCo } = await pool.query('SELECT id FROM workout_schedules');
  if (scheduleCo === 0) {
    const today = new Date();
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    await pool.query(
      `INSERT INTO workout_schedules(user_id, menu_id, scheduled_date, is_completed) VALUES
        (1, 1, $1, false),
        (1, 2, $2, false),
        (1, 1, $3, true);`,
      [today, tomorrow, yesterday]
    );
    console.log('Mock schedules created.');
  }

  const { rowCount: tokenTypeCo } = await pool.query('SELECT id FROM token_types');
  if (tokenTypeCo === 0) {
    await pool.query(
      `INSERT INTO token_types(id, name, default_amount) VALUES
       (1, 'Workout Complete', 10), (2, 'Menu Published', 50);`
    );
    console.log('Mock token types created.');
  }

  const { rowCount: tokenLogCo } = await pool.query('SELECT id FROM token_logs');
  if (tokenLogCo === 0) {
    await pool.query(
      `INSERT INTO token_logs(user_id, token_type_id, amount) VALUES
        (1, 1, 10), (1, 1, 10), (1, 2, 50);`
    );
    console.log('Mock token logs created.');
  }
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

// --- Schedules API ---
app.get('/schedules', async (req, res) => {
  try {
    const query = `
      SELECT 
        ws.id, 
        ws.scheduled_date, 
        ws.is_completed, 
        m.title as menu_title, 
        m.difficulty as menu_difficulty 
      FROM workout_schedules ws
      JOIN menus m ON ws.menu_id = m.id
      WHERE ws.user_id = 1 -- Mock user_id
      ORDER BY ws.scheduled_date ASC, ws.is_completed ASC;
    `;
    const { rows } = await pool.query(query);
    res.status(200).json(rows);
  } catch (err) {
    console.error('Error fetching schedules:', err);
    res.status(500).json({ message: 'Error fetching schedules' });
  }
});

app.patch('/schedules/:id/complete', async (req, res) => {
    const { id } = req.params;
    try {
        const { rowCount } = await pool.query(
            'UPDATE workout_schedules SET is_completed = true WHERE id = $1 AND user_id = 1', // Mock user_id
            [id]
        );
        if (rowCount === 0) {
            return res.status(404).json({ message: 'Schedule not found or not owned by user' });
        }
        res.status(200).json({ message: 'Schedule marked as complete' });
    } catch(err) {
        console.error(`Error completing schedule ${id}:`, err);
        res.status(500).json({ message: 'Error completing schedule' });
    }
});

app.delete('/schedules/:id', async (req, res) => {
    const { id } = req.params;
    try {
        const { rowCount } = await pool.query(
            'DELETE FROM workout_schedules WHERE id = $1 AND user_id = 1', // Mock user_id
            [id]
        );
         if (rowCount === 0) {
            return res.status(404).json({ message: 'Schedule not found or not owned by user' });
        }
        res.status(200).json({ message: 'Schedule deleted successfully' });
    } catch(err) {
        console.error(`Error deleting schedule ${id}:`, err);
        res.status(500).json({ message: 'Error deleting schedule' });
    }
});


// --- Token API ---
app.get('/token-summary', async (req, res) => {
    try {
        const totalQuery = `SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) as total_tokens FROM token_logs WHERE user_id = 1;`; // Mock user_id
        const historyQuery = `
            SELECT tl.amount, tl.created_at, tt.name as type_name
            FROM token_logs tl
            JOIN token_types tt ON tl.token_type_id = tt.id
            WHERE tl.user_id = 1 -- Mock user_id
            ORDER BY tl.created_at DESC
            LIMIT 5;
        `;
        const [totalRes, historyRes] = await Promise.all([
            pool.query(totalQuery),
            pool.query(historyQuery)
        ]);
        
        const totalTokens = totalRes.rows[0].total_tokens || 0;
        const history = historyRes.rows;

        res.status(200).json({ totalTokens, history });

    } catch (err) {
        console.error('Error fetching token summary:', err);
        res.status(500).json({ message: 'Error fetching token summary' });
    }
});


app.get('/', (req, res) => {
  res.send('Backend server is running!');
});

async function startServer() {
  try {
    await waitForDb();
    await createTables();
    await seedData(); // Seed mock data after creating tables

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
