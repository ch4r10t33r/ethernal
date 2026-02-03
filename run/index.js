const { execSync } = require('child_process');
const logger = require('./lib/logger');
const app = require('./app');

// Run migrations before accepting traffic so schema is ready (e.g. for pm2 syncExplorers).
try {
    execSync('sequelize db:migrate', { stdio: 'inherit', env: process.env });
} catch (e) {
    logger.error('Migrations failed', { error: e.message });
    process.exit(1);
}

const port = parseInt(process.env.PORT) || 6000;
app.listen(port, '::', () => {
    console.log(process.env.NODE_ENV == 'development' ? process.env : `App started on port ${port}`);
    logger.info(`Listening on port ${port}`);
});
