const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
const port = 3000;

app.use(cors()); // Enable CORS for all routes
app.use(bodyParser.json());

// Mock user data (simulating DynamoDB)
const users = [
  { username: 'user', password: 'password', id: '1' },
  { username: 'admin', password: 'admin', id: '2' },
];

app.post('/login', (req, res) => {
  const { username, password } = req.body;

  console.log(`Login attempt for username: ${username}`);

  const user = users.find(u => u.username === username && u.password === password);

  if (user) {
    console.log(`User ${username} logged in successfully.`);
    // In a real app, you'd generate a token here (JWT)
    res.status(200).json({ message: 'Login successful', user: { id: user.id, username: user.username } });
  } else {
    console.log(`Login failed for username: ${username}. Invalid credentials.`);
    res.status(401).json({ message: 'Invalid credentials' });
  }
});

app.listen(port, () => {
  console.log(`Backend server listening at http://localhost:${port}`);
});
