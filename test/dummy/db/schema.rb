# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_12_04_121532) do

  create_table "aikotoba_accounts", force: :cascade do |t|
    t.string "authenticate_target_type"
    t.integer "authenticate_target_id"
    t.integer "strategy", null: false
    t.string "email"
    t.string "password_digest", null: false
    t.boolean "confirmed", default: false, null: false
    t.string "confirm_token"
    t.integer "failed_attempts", default: 0, null: false
    t.boolean "locked", default: false, null: false
    t.string "unlock_token"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["authenticate_target_type", "authenticate_target_id"], name: "authenticate_target"
    t.index ["confirm_token"], name: "index_aikotoba_accounts_on_confirm_token", unique: true
    t.index ["email"], name: "index_aikotoba_accounts_on_email", unique: true
    t.index ["password_digest"], name: "index_aikotoba_accounts_on_password_digest"
    t.index ["unlock_token"], name: "index_aikotoba_accounts_on_unlock_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "nickname"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

end
