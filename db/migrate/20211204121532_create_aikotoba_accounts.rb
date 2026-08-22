class CreateAikotobaAccounts < ActiveRecord::Migration[6.1]
  # NOTE: The tables below the "optional features" marker belong to features that are
  #       disabled by default (Aikotoba.confirmable / .lockable / .recoverable /
  #       .magic_link_authenticatable / .api_authenticatable all default to false), so
  #       they ship commented out. Uncomment the block for each feature you enable --
  #       before running db:migrate on a fresh install, or in a new migration of your
  #       own if you enable the feature later.
  #
  #       Leaving them commented out is safe: Aikotoba never queries a feature's table
  #       while that table does not exist, including on Account#destroy! and session
  #       revocation. The reverse is not true -- enabling a feature's flag without its
  #       table raises a real database error the first time that feature runs.
  def change
    create_table :aikotoba_accounts do |t|
      t.belongs_to :authenticate_target, polymorphic: true, index: {unique: true}
      t.string :email, null: false, index: {unique: true}
      t.boolean :confirmed, null: false, default: false
      t.integer :failed_attempts, null: false, default: 0
      t.boolean :locked, null: false, default: false

      t.timestamps
    end

    create_table :aikotoba_account_password_hashes do |t|
      t.belongs_to(
        :aikotoba_account,
        null: false, foreign_key: true,
        index: {unique: true, name: "index_account_password_hashes_on_account_id"}
      )
      t.string :digest, null: false

      t.timestamps
    end

    create_table :aikotoba_account_sessions do |t|
      t.belongs_to :aikotoba_account, null: false, foreign_key: true
      t.string :token, null: false, index: {unique: true}
      t.string :origin, null: false, default: "browser"
      t.string :ip_address
      t.string :user_agent
      t.datetime :expired_at, null: false

      t.timestamps
    end

    # ------------------------------------------------------------------
    # Optional features -- uncomment the ones you enable. See the NOTE above.
    # ------------------------------------------------------------------

    # Aikotoba.confirmable = true
    #
    # create_table :aikotoba_account_confirmation_tokens do |t|
    #   t.belongs_to(
    #     :aikotoba_account,
    #     foreign_key: true, null: false,
    #     index: {unique: true, name: "index_account_confirmation_tokens_on_account_id"}
    #   )
    #   t.string :token, null: false, index: {unique: true}
    #   t.datetime :expired_at, null: false
    #
    #   t.timestamps
    # end

    # Aikotoba.lockable = true
    #
    # create_table :aikotoba_account_unlock_tokens do |t|
    #   t.belongs_to(
    #     :aikotoba_account,
    #     null: false, foreign_key: true,
    #     index: {unique: true, name: "index_account_unlock_tokens_on_account_id"}
    #   )
    #   t.string :token, null: false, index: {unique: true}
    #   t.datetime :expired_at, null: false
    #
    #   t.timestamps
    # end

    # Aikotoba.recoverable = true
    #
    # create_table :aikotoba_account_recovery_tokens do |t|
    #   t.belongs_to(
    #     :aikotoba_account,
    #     null: false, foreign_key: true,
    #     index: {unique: true, name: "index_account_recovery_tokens_on_account_id"}
    #   )
    #   t.string :token, null: false, index: {unique: true}
    #   t.datetime :expired_at, null: false
    #
    #   t.timestamps
    # end

    # Aikotoba.magic_link_authenticatable = true
    #
    # create_table :aikotoba_account_magic_link_tokens do |t|
    #   t.belongs_to(
    #     :aikotoba_account,
    #     null: false, foreign_key: true,
    #     index: {unique: true, name: "index_account_magic_link_tokens_on_account_id"}
    #   )
    #   t.string :token, null: false, index: {unique: true}
    #   t.datetime :expired_at, null: false
    #
    #   t.timestamps
    # end

    # Aikotoba.api_authenticatable = true
    #
    # create_table :aikotoba_account_refresh_tokens do |t|
    #   t.belongs_to :aikotoba_account_session,
    #     null: false,
    #     foreign_key: true,
    #     index: {unique: true, name: "idx_aikotoba_refresh_tokens_on_session_id"}
    #   t.string :token, null: false, index: {unique: true}
    #   t.datetime :expired_at, null: false
    #
    #   t.timestamps
    # end
  end
end
