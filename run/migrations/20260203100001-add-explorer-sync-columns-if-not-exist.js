'use strict';

/**
 * Idempotent backstop: adds explorer sync-failure columns only if they don't exist.
 * One statement per query for reliable execution across drivers.
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface) {
    const { sequelize } = queryInterface;
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

  async down() {
    // No-op: leave schema as-is to avoid breaking either migration path.
  }
};
