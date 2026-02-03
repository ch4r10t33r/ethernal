'use strict';

/**
 * Idempotent migration: adds explorer sync-failure columns only if they don't exist.
 * Use when DB may already have them (from 20260109161142) or may not (e.g. older deployment).
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface) {
    const { sequelize } = queryInterface;
    await sequelize.query(`
      ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "syncFailedAttempts" INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "syncDisabledAt" TIMESTAMP WITH TIME ZONE;
      ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "syncDisabledReason" VARCHAR(255);
      ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "recoveryAttempts" INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE "explorers" ADD COLUMN IF NOT EXISTS "nextRecoveryCheckAt" TIMESTAMP WITH TIME ZONE;
    `);
    await sequelize.query(`
      CREATE INDEX IF NOT EXISTS "explorers_next_recovery_check_at_idx"
      ON "explorers" ("nextRecoveryCheckAt")
      WHERE "nextRecoveryCheckAt" IS NOT NULL;
    `);
  },

  async down() {
    // No-op: down would require knowing if we added the columns; leave schema as-is.
  }
};
