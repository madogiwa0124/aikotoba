class CreateAikotobaAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :aikotoba_accounts do |t|
      t.belongs_to :authenticate_target, polymorphic: true
      t.string :email, null: false, index: {unique: true}
      t.string :password_digest, null: false

      # for confirmable
      t.boolean :confirmed, null: false, default: false
      t.string :confirmation_token, index: {unique: true}

      # for lockable
      t.integer :failed_attempts, null: false, default: 0
      t.boolean :locked, null: false, default: false
      t.string :unlock_token, index: {unique: true}

      # for recoverable
      t.string :recovery_token, index: {unique: true}

      t.timestamps
    end
  end
end
