class CreateDummyTables < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :nickname

      t.timestamps
    end

    create_table :admins do |t|
      t.string :nickname

      t.timestamps
    end
  end
end
