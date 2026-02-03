/**
 * @fileoverview PM2 Server entry point.
 * Starts Express server and triggers explorer sync on startup.
 * @module pm2-server/index
 */

const axios = require('axios');
const app = require('./app.js');

const port = process.env.PORT || 9090;

const triggerSync = () => {
    const host = process.env.ETHERNAL_HOST;
    const secret = process.env.ETHERNAL_SECRET;
    if (!host || !secret) {
        console.error('ETHERNAL_HOST or ETHERNAL_SECRET not set. Set them in pm2-server/.env.prod (e.g. ETHERNAL_HOST=http://backend:8888).');
        setTimeout(triggerSync, 5000);
        return;
    }
    axios.post(`${host}/api/explorers/syncExplorers?secret=${secret}`)
        .then(({ data }) => console.log(data))
        .catch((error) => {
            console.log(`Error when starting sync. Trying again in 1 second...`);
            console.log(error);
            setTimeout(triggerSync, 1000);
        });
};

app.listen(port, () => {
    console.log(`App is listening on port ${port}`);
    triggerSync();
});
