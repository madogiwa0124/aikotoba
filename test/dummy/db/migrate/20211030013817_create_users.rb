class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :secret_digest

      t.timestamps
    end
  end
end
