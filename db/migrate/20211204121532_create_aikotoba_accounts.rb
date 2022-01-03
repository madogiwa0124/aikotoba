class CreateAikotobaAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :aikotoba_accounts do |t|
      t.belongs_to :authenticate_target, polymorphic: true, index: {unique: true}
      t.string :email, null: false, index: {unique: true}
      t.string :password_digest, null: false
      t.boolean :confirmed, null: false, default: false
      t.integer :failed_attempts, null: false, default: 0
      t.boolean :locked, null: false, default: false

      t.timestamps
    end

    create_table :aikotoba_account_confirmation_tokens do |t|
      t.belongs_to(
        :aikotoba_account,
        foreign_key: true, null: false,
        index: {unique: true, name: "index_account_confirmation_tokens_on_account_id"}
      )
      t.string :token, null: false, index: {unique: true}

      t.timestamps
    end

    create_table :aikotoba_account_unlock_tokens do |t|
      t.belongs_to(
        :aikotoba_account,
        null: false, foreign_key: true,
        index: {unique: true, name: "index_account_unlock_tokens_on_account_id"}
      )
      t.string :token, null: false, index: {unique: true}

      t.timestamps
    end

    create_table :aikotoba_account_recovery_tokens do |t|
      t.belongs_to(
        :aikotoba_account,
        null: false, foreign_key: true,
        index: {unique: true, name: "index_account_recovery_tokens_on_account_id"}
      )
      t.string :token, null: false, index: {unique: true}

      t.timestamps
    end
  end
end
