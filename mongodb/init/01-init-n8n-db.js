// MongoDB initialization script for root and n8n users
// This script runs only on first initialization (when database is empty)
// Scripts in /docker-entrypoint-initdb.d/ run with admin privileges, no auth needed

// Get root user credentials from environment
const rootUser = process.env.MONGO_INITDB_ROOT_USERNAME || 'admin';
const rootPassword = process.env.MONGO_INITDB_ROOT_PASSWORD || '';

// Get files database name from environment
const filesDbName = process.env.MONGO_INITDB_DATABASE || 'files';

// Get n8n database name and credentials from environment
const n8nDbName = process.env.N8N_MONGODB_DATABASE || 'n8n';
const n8nUser = process.env.N8N_MONGODB_USER || 'n8n';
const n8nPassword = process.env.N8N_MONGODB_PASSWORD || '';

print('Initializing MongoDB users and databases...');

// Switch to admin database
db = db.getSiblingDB('admin');

// Create root user if password is provided
if (rootPassword) {
  print('Creating root user: ' + rootUser);
  try {
    db.createUser({
      user: rootUser,
      pwd: rootPassword,
      roles: ['root']
    });
    print('Root user ' + rootUser + ' created successfully');
  } catch (error) {
    if (error.code === 51003 || error.codeName === 'DuplicateKey') {
      print('Root user ' + rootUser + ' already exists, updating password...');
      db.updateUser(rootUser, {
        pwd: rootPassword
      });
      print('Root user password updated');
    } else {
      print('Error creating root user: ' + error);
      throw error;
    }
  }
} else {
  print('Warning: MONGO_INITDB_ROOT_PASSWORD is not set. MongoDB will run without authentication.');
}

// Create user for n8n database
// Users are stored in admin database but granted access to specific database
print('Creating n8n user: ' + n8nUser);
print('Database: ' + n8nDbName);

// Only create n8n user if password is provided
if (n8nPassword) {
  try {
    db.createUser({
      user: n8nUser,
      pwd: n8nPassword,
      roles: [
        {
          role: 'readWrite',
          db: n8nDbName
        }
      ]
    });
    print('User ' + n8nUser + ' created successfully');
  } catch (error) {
    if (error.code === 51003 || error.codeName === 'DuplicateKey') {
      // User already exists
      print('User ' + n8nUser + ' already exists, updating password...');
      db.updateUser(n8nUser, {
        pwd: n8nPassword
      });
      print('Password updated for user ' + n8nUser);
    } else {
      print('Error creating user: ' + error);
      // Don't throw - continue to create databases even if user creation fails
      print('Warning: Continuing without n8n user...');
    }
  }
} else {
  print('Warning: N8N_MONGODB_PASSWORD is not set. Skipping n8n user creation.');
}

// Create files database (if specified)
if (filesDbName && filesDbName !== 'admin') {
  print('Creating files database: ' + filesDbName);
  try {
    db = db.getSiblingDB(filesDbName);
    db.createCollection('_init');
    db._init.insertOne({ initialized: true, timestamp: new Date() });
    print('Files database ' + filesDbName + ' created successfully');
  } catch (error) {
    print('Error creating files database: ' + error);
    // Continue anyway
  }
}

// Switch to n8n database and create a test collection to ensure database is created
print('Creating n8n database: ' + n8nDbName);
try {
  db = db.getSiblingDB(n8nDbName);
  db.createCollection('_init');
  db._init.insertOne({ initialized: true, timestamp: new Date() });
  print('n8n database ' + n8nDbName + ' initialized successfully');
} catch (error) {
  print('Error creating n8n database: ' + error);
  // Continue anyway
}

print('MongoDB initialization completed');

