'use strict';

/**
 * Idempotent: adds explorer sync-failure columns and index.
 * Uses IF NOT EXISTS so safe on fresh DBs and when columns already exist (e.g. retry after partial run).
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface) {
    const { sequelize } = queryInterface;
    // One statement per query so every driver/version executes all (no multi-statement ambiguity).
    await sequelize.query('ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "syncFailedAttempts" INTEGER NOT NULL DEFAULT 0');
    await sequelize.query('ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "syncDisabledAt" TIMESTAMP WITH TIME ZONE');
    await sequelize.query('ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "syncDisabledReason" VARCHAR(255)');
    await sequelize.query('ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "recoveryAttempts" INTEGER NOT NULL DEFAULT 0');
    await sequelize.query('ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "nextRecoveryCheckAt" TIMESTAMP WITH TIME ZONE');
    await sequelize.query(`
      CREATE INDEX IF NOT EXISTS "explorers_next_recovery_check_at_idx"
      ON "explorers" ("nextRecoveryCheckAt")
      WHERE "nextRecoveryCheckAt" IS NOT NULL
    `);
  },

  async down(queryInterface) {
    const { sequelize } = queryInterface;
    await sequelize.query('DROP INDEX IF EXISTS "explorers_next_recovery_check_at_idx"');
    await queryInterface.removeColumn('explorers', 'syncFailedAttempts').catch(() => {});
    await queryInterface.removeColumn('explorers', 'syncDisabledAt').catch(() => {});
    await queryInterface.removeColumn('explorers', 'syncDisabledReason').catch(() => {});
    await queryInterface.removeColumn('explorers', 'recoveryAttempts').catch(() => {});
    await queryInterface.removeColumn('explorers', 'nextRecoveryCheckAt').catch(() => {});
  }
};
