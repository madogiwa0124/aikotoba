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

  create_table "aikotoba_account_confirmation_tokens", force: :cascade do |t|
    t.integer "aikotoba_account_id", null: false
    t.string "token", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["aikotoba_account_id"], name: "index_account_confirmation_tokens_on_account_id", unique: true
    t.index ["token"], name: "index_aikotoba_account_confirmation_tokens_on_token", unique: true
  end

  create_table "aikotoba_account_recovery_tokens", force: :cascade do |t|
    t.integer "aikotoba_account_id", null: false
    t.string "token", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["aikotoba_account_id"], name: "index_account_recovery_tokens_on_account_id", unique: true
    t.index ["token"], name: "index_aikotoba_account_recovery_tokens_on_token", unique: true
  end

  create_table "aikotoba_account_unlock_tokens", force: :cascade do |t|
    t.integer "aikotoba_account_id", null: false
    t.string "token", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["aikotoba_account_id"], name: "index_account_unlock_tokens_on_account_id", unique: true
    t.index ["token"], name: "index_aikotoba_account_unlock_tokens_on_token", unique: true
  end

  create_table "aikotoba_accounts", force: :cascade do |t|
    t.string "authenticate_target_type"
    t.integer "authenticate_target_id"
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "confirmed", default: false, null: false
    t.integer "failed_attempts", default: 0, null: false
    t.boolean "locked", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["authenticate_target_type", "authenticate_target_id"], name: "index_aikotoba_accounts_on_authenticate_target", unique: true
    t.index ["email"], name: "index_aikotoba_accounts_on_email", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "nickname"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "aikotoba_account_confirmation_tokens", "aikotoba_accounts"
  add_foreign_key "aikotoba_account_recovery_tokens", "aikotoba_accounts"
  add_foreign_key "aikotoba_account_unlock_tokens", "aikotoba_accounts"
end
