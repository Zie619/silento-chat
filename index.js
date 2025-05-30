// Render entry point - redirects to compiled server
// Render keeps trying to run 'node index.js' despite our configuration
console.log('Starting Silento backend server...');

// Set production environment
process.env.NODE_ENV = 'production';

// Import and start the compiled server
import('./dist/server/index.js').catch(error => {
  console.error('Failed to start server:', error);
  process.exit(1);
}); 