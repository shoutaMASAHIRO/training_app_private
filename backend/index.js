const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const AWS = require('aws-sdk');
const bcrypt = require('bcryptjs');

// Initialize Express app
const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());

// AWS DynamoDB Configuration
const { AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, DYNAMODB_ENDPOINT } = process.env;

AWS.config.update({
    region: AWS_REGION,
    accessKeyId: AWS_ACCESS_KEY_ID,
    secretAccessKey: AWS_SECRET_ACCESS_KEY,
    endpoint: DYNAMODB_ENDPOINT
});

const dynamodb = new AWS.DynamoDB();
const docClient = new AWS.DynamoDB.DocumentClient();
const tableName = 'Users';

// Helper function to create table if it doesn't exist
const createTable = async () => {
    const params = {
        TableName: tableName,
        KeySchema: [
            { AttributeName: 'username', KeyType: 'HASH' } // Partition key
        ],
        AttributeDefinitions: [
            { AttributeName: 'username', AttributeType: 'S' }
        ],
        ProvisionedThroughput: {
            ReadCapacityUnits: 5,
            WriteCapacityUnits: 5
        }
    };

    try {
        const tables = await dynamodb.listTables({}).promise();
        if (!tables.TableNames.includes(tableName)) {
            await dynamodb.createTable(params).promise();
            console.log(`Table '${tableName}' created successfully.`);
        } else {
            console.log(`Table '${tableName}' already exists.`);
        }
    } catch (err) {
        console.error("Error creating table:", err);
    }
};

// --- API Endpoints ---

// Register a new user
app.post('/register', async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ message: 'Username and password are required' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const params = {
        TableName: tableName,
        Item: {
            username: username,
            password: hashedPassword
        },
        ConditionExpression: 'attribute_not_exists(username)' // Fail if username already exists
    };

    try {
        await docClient.put(params).promise();
        res.status(201).json({ message: 'User registered successfully' });
    } catch (err) {
        if (err.code === 'ConditionalCheckFailedException') {
            return res.status(409).json({ message: 'Username already exists' });
        }
        console.error('Error registering user:', err);
        res.status(500).json({ message: 'Error registering user' });
    }
});

// Login a user
app.post('/login', async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ message: 'Username and password are required' });
    }

    const params = {
        TableName: tableName,
        Key: {
            username: username
        }
    };

    try {
        const { Item } = await docClient.get(params).promise();

        if (!Item) {
            return res.status(404).json({ message: 'User not found' });
        }

        const isMatch = await bcrypt.compare(password, Item.password);

        if (!isMatch) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        // In a real app, you would generate and return a JWT here
        res.status(200).json({ message: 'Login successful' });

    } catch (err) {
        console.error('Error logging in user:', err);
        res.status(500).json({ message: 'Error logging in user' });
    }
});


// Root endpoint
app.get('/', (req, res) => {
    res.send('Backend server is running!');
});

// Start the server
app.listen(PORT, async () => {
    console.log(`Server is running on http://localhost:${PORT}`);
    await createTable();
});
