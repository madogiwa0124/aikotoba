class CreateAikotobaAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :aikotoba_accounts do |t|
      t.belongs_to(
        :authenticate_target,
        polymorphic: true,
        index: {name: "authenticate_target"}
      )
      t.integer :strategy, null: false
      t.string :email, index: {unique: true}
      t.string :password_digest, null: false, index: true
      t.boolean :confirmed, null: false, default: false
      t.string :confirm_token, index: {unique: true}
      t.timestamps
    end
  end
end
