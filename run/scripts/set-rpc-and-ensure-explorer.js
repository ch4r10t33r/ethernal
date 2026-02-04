/**
 * One-off script: set workspace RPC to a given URL and ensure each workspace has an explorer
 * so indexing can run. Creates explorer via safeCreateExplorer when missing and enqueues initial blockSync.
 *
 * Usage (from run/): node scripts/set-rpc-and-ensure-explorer.js [RPC_URL]
 * Default RPC_URL: http://l1rpc.native-rollup.xyz
 *
 * Requires: DATABASE_URL, REDIS_URL (and same env as app). Restart workers after running.
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const models = require('../models');
const { enqueue } = require('../lib/queue');

const { Workspace, User } = models;

const RPC_URL = process.argv[2] || process.env.RPC_URL || 'http://l1rpc.native-rollup.xyz';

async function main() {
    const workspaces = await Workspace.findAll({
        include: [
            { model: User, as: 'user', attributes: ['id', 'firebaseUserId'] },
            { model: models.Explorer, as: 'explorer', required: false }
        ]
    });

    console.log(`Found ${workspaces.length} workspace(s). Setting RPC to ${RPC_URL}.`);

    for (const ws of workspaces) {
        await ws.update({ rpcServer: RPC_URL });
        console.log(`  Updated workspace "${ws.name}" (id=${ws.id}) RPC.`);

        if (!ws.explorer) {
            console.log(`  No explorer for "${ws.name}" – creating one and starting sync.`);
            const explorer = await models.sequelize.transaction((t) => ws.safeCreateExplorer(t));
            if (!explorer) {
                console.warn(`  Failed to create explorer for workspace ${ws.id}.`);
                continue;
            }
            await explorer.startSync();
            const startBlock = ws.integrityCheckStartBlockNumber ?? 0;
            await enqueue('blockSync', `blockSync-${ws.id}-${startBlock}`, {
                userId: ws.user.firebaseUserId,
                workspace: ws.name,
                blockNumber: startBlock,
                source: 'script'
            }, 1);
            console.log(`  Created explorer id=${explorer.id}, enqueued blockSync from block ${startBlock}.`);
        }
    }

    console.log('Done. Restart backend/workers to pick up changes and run indexing.');
    process.exit(0);
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
