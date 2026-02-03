'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('explorers', 'syncFailedAttempts', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0
    });
    await queryInterface.addColumn('explorers', 'syncDisabledAt', {
      type: Sequelize.DATE,
      allowNull: true
    });
    await queryInterface.addColumn('explorers', 'syncDisabledReason', {
      type: Sequelize.STRING,
      allowNull: true
    });
    await queryInterface.addColumn('explorers', 'recoveryAttempts', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0
    });
    await queryInterface.addColumn('explorers', 'nextRecoveryCheckAt', {
      type: Sequelize.DATE,
      allowNull: true
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('explorers', 'syncFailedAttempts');
    await queryInterface.removeColumn('explorers', 'syncDisabledAt');
    await queryInterface.removeColumn('explorers', 'syncDisabledReason');
    await queryInterface.removeColumn('explorers', 'recoveryAttempts');
    await queryInterface.removeColumn('explorers', 'nextRecoveryCheckAt');
  }
};
