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
        is_completed BOOLEAN DEFAULT false,
        workout_details TEXT
    );
    `,
    // workout_detailsカラムが既存テーブルにない場合は追加
    `
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                     WHERE table_name='workout_schedules' AND column_name='workout_details') THEN
        ALTER TABLE workout_schedules ADD COLUMN workout_details TEXT;
      END IF;
    END $$;
    `,
    `
    CREATE TABLE IF NOT EXISTS workout_logs (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL DEFAULT 1,
        completed_date DATE NOT NULL,
        menu_title VARCHAR(255) NOT NULL,
        workout_details TEXT,
        success_count INTEGER DEFAULT 0,
        fail_count INTEGER DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
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
  // デフォルトユーザーは作成しない（ユーザー自身で登録する）

  // テンプレートメニューを作成（creator_idはNULL）
  const { rowCount: menuCo } = await pool.query('SELECT id FROM menus');
  if (menuCo === 0) {
    await pool.query(
      `INSERT INTO menus(id, creator_id, title, concept, difficulty, is_template, is_public) VALUES
        (1, NULL, 'Smolov Jr.', '3-week high frequency strength program', 'Advanced', true, true),
        (2, NULL, '10x10', 'German Volume Training', 'Intermediate', true, true);`
    );
    console.log('Template menus created.');
  }

  // Smolov Jr.メニューが存在しない場合は追加
  const { rowCount: smolovCheck } = await pool.query("SELECT id FROM menus WHERE title = 'Smolov Jr.'");
  if (smolovCheck === 0) {
    await pool.query(
      `INSERT INTO menus(creator_id, title, concept, difficulty, is_template, is_public) VALUES
        (NULL, 'Smolov Jr.', '3-week high frequency strength program', 'Advanced', true, true);`
    );
    console.log('Smolov Jr. menu created.');
  }

  // デフォルトスケジュールは作成しない（ユーザーがSmolov Jr.等を登録する）

  const { rowCount: tokenTypeCo } = await pool.query('SELECT id FROM token_types');
  if (tokenTypeCo === 0) {
    await pool.query(
      `INSERT INTO token_types(id, name, default_amount) VALUES
       (1, 'Workout Complete', 10), (2, 'Menu Published', 50);`
    );
    console.log('Mock token types created.');
  }

  // デフォルトのtoken_logsは作成しない（ユーザー登録後に作成される）
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
        m.difficulty as menu_difficulty,
        ws.workout_details
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

// POST /schedules - 新しいスケジュールを追加
app.post('/schedules', async (req, res) => {
    const { scheduled_date, menu_title, menu_difficulty, workout_details } = req.body;

    if (!scheduled_date || !menu_title) {
        return res.status(400).json({ message: 'scheduled_date and menu_title are required' });
    }

    try {
        // メニューをタイトルで検索、なければ作成
        let menuResult = await pool.query('SELECT id FROM menus WHERE title = $1', [menu_title]);

        let menuId;
        if (menuResult.rows.length === 0) {
            // メニューが存在しない場合は作成
            const insertMenu = await pool.query(
                `INSERT INTO menus(creator_id, title, difficulty, is_template, is_public)
                 VALUES (1, $1, $2, true, true) RETURNING id`,
                [menu_title, menu_difficulty || 'Intermediate']
            );
            menuId = insertMenu.rows[0].id;
            console.log(`Created new menu: ${menu_title} with id ${menuId}`);
        } else {
            menuId = menuResult.rows[0].id;
        }

        // スケジュールを挿入
        const insertSchedule = await pool.query(
            `INSERT INTO workout_schedules(user_id, menu_id, scheduled_date, is_completed, workout_details)
             VALUES (1, $1, $2, false, $3) RETURNING id, scheduled_date, is_completed, workout_details`,
            [menuId, scheduled_date, workout_details || null]
        );

        const newSchedule = insertSchedule.rows[0];
        res.status(201).json({
            id: newSchedule.id,
            scheduled_date: newSchedule.scheduled_date,
            is_completed: newSchedule.is_completed,
            menu_title: menu_title,
            menu_difficulty: menu_difficulty || 'Intermediate',
            workout_details: newSchedule.workout_details
        });
    } catch (err) {
        console.error('Error creating schedule:', err);
        res.status(500).json({ message: 'Error creating schedule', error: err.message });
    }
});

// DELETE /schedules/by-menu/:menuTitle - 特定メニューのスケジュールを一括削除
app.delete('/schedules/by-menu/:menuTitle', async (req, res) => {
    const { menuTitle } = req.params;
    try {
        // メニューIDを取得
        const menuResult = await pool.query('SELECT id FROM menus WHERE title = $1', [menuTitle]);
        if (menuResult.rows.length === 0) {
            return res.status(200).json({ message: 'No schedules to delete', deleted: 0 });
        }

        const menuId = menuResult.rows[0].id;
        const { rowCount } = await pool.query(
            'DELETE FROM workout_schedules WHERE menu_id = $1 AND user_id = 1',
            [menuId]
        );

        res.status(200).json({ message: 'Schedules deleted successfully', deleted: rowCount });
    } catch (err) {
        console.error(`Error deleting schedules for menu ${menuTitle}:`, err);
        res.status(500).json({ message: 'Error deleting schedules' });
    }
});

// --- Workout Logs API ---
// GET /logs - ワークアウトログ一覧取得
app.get('/logs', async (req, res) => {
    try {
        const query = `
            SELECT id, completed_date, menu_title, workout_details, success_count, fail_count, created_at
            FROM workout_logs
            WHERE user_id = 1
            ORDER BY completed_date DESC, created_at DESC;
        `;
        const { rows } = await pool.query(query);
        res.status(200).json(rows);
    } catch (err) {
        console.error('Error fetching logs:', err);
        res.status(500).json({ message: 'Error fetching logs' });
    }
});

// POST /logs - ワークアウトログ追加
app.post('/logs', async (req, res) => {
    const { completed_date, menu_title, workout_details, success_count, fail_count } = req.body;

    if (!completed_date || !menu_title) {
        return res.status(400).json({ message: 'completed_date and menu_title are required' });
    }

    try {
        const insertLog = await pool.query(
            `INSERT INTO workout_logs(user_id, completed_date, menu_title, workout_details, success_count, fail_count)
             VALUES (1, $1, $2, $3, $4, $5)
             RETURNING id, completed_date, menu_title, workout_details, success_count, fail_count, created_at`,
            [completed_date, menu_title, workout_details || null, success_count || 0, fail_count || 0]
        );

        res.status(201).json(insertLog.rows[0]);
    } catch (err) {
        console.error('Error creating log:', err);
        res.status(500).json({ message: 'Error creating log', error: err.message });
    }
});

// DELETE /logs/:id - 特定のログを削除
app.delete('/logs/:id', async (req, res) => {
    const { id } = req.params;
    try {
        const { rowCount } = await pool.query(
            'DELETE FROM workout_logs WHERE id = $1 AND user_id = 1',
            [id]
        );
        if (rowCount === 0) {
            return res.status(404).json({ message: 'Log not found' });
        }
        res.status(200).json({ message: 'Log deleted successfully' });
    } catch (err) {
        console.error(`Error deleting log ${id}:`, err);
        res.status(500).json({ message: 'Error deleting log' });
    }
});

// DELETE /logs/by-date/:date - 特定日のログを全削除
app.delete('/logs/by-date/:date', async (req, res) => {
    const { date } = req.params;
    try {
        const { rowCount } = await pool.query(
            'DELETE FROM workout_logs WHERE completed_date = $1 AND user_id = 1',
            [date]
        );
        res.status(200).json({ message: 'Logs deleted successfully', deleted: rowCount });
    } catch (err) {
        console.error(`Error deleting logs for date ${date}:`, err);
        res.status(500).json({ message: 'Error deleting logs' });
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
