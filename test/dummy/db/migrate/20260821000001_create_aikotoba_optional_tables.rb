# NOTE: The dummy app is a host app that exercises every Aikotoba feature, so it needs
#       every optional feature's table. Those ship commented out in the engine's
#       canonical migration (see db/migrate/20211204121532_create_aikotoba_accounts.rb),
#       because all five features default to false -- a host app uncomments the blocks it
#       wants. The dummy can't uncomment a file it doesn't own, so it does the same thing
#       the "I enabled this feature later" path in the README describes: create the tables
#       in a migration of its own. Keep this in sync with the commented-out blocks.
class CreateAikotobaOptionalTables < ActiveRecord::Migration[6.1]
  def change
    create_table :aikotoba_account_confirmation_tokens do |t|
      t.belongs_to(
        :aikotoba_account,
        foreign_key: true, null: false,
        index: {unique: true, name: "index_account_confirmation_tokens_on_account_id"}
      )
      t.string :token, null: false, index: {unique: true}
      t.datetime :expired_at, null: false

      t.timestamps
    end

    create_table :aikotoba_account_unlock_tokens do |t|
      t.belongs_to(
        :aikotoba_account,
        null: false, foreign_key: true,
        index: {unique: true, name: "index_account_unlock_tokens_on_account_id"}
      )
      t.string :token, null: false, index: {unique: true}
      t.datetime :expired_at, null: false

      t.timestamps
    end

    create_table :aikotoba_account_recovery_tokens do |t|
      t.belongs_to(
        :aikotoba_account,
        null: false, foreign_key: true,
        index: {unique: true, name: "index_account_recovery_tokens_on_account_id"}
      )
      t.string :token, null: false, index: {unique: true}
      t.datetime :expired_at, null: false

      t.timestamps
    end

    create_table :aikotoba_account_magic_link_tokens do |t|
      t.belongs_to(
        :aikotoba_account,
        null: false, foreign_key: true,
        index: {unique: true, name: "index_account_magic_link_tokens_on_account_id"}
      )
      t.string :token, null: false, index: {unique: true}
      t.datetime :expired_at, null: false

      t.timestamps
    end

    create_table :aikotoba_account_refresh_tokens do |t|
      t.belongs_to :aikotoba_account_session,
        null: false,
        foreign_key: true,
        index: {unique: true, name: "idx_aikotoba_refresh_tokens_on_session_id"}
      t.string :token, null: false, index: {unique: true}
      t.datetime :expired_at, null: false

      t.timestamps
    end
  end
end
