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

ActiveRecord::Schema[8.1].define(version: 2026_02_23_000100) do
  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nickname"
    t.datetime "updated_at", null: false
  end

  create_table "aikotoba_account_confirmation_tokens", force: :cascade do |t|
    t.integer "aikotoba_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expired_at", precision: nil, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["aikotoba_account_id"], name: "index_account_confirmation_tokens_on_account_id", unique: true
    t.index ["token"], name: "index_aikotoba_account_confirmation_tokens_on_token", unique: true
  end

  create_table "aikotoba_account_recovery_tokens", force: :cascade do |t|
    t.integer "aikotoba_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expired_at", precision: nil, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["aikotoba_account_id"], name: "index_account_recovery_tokens_on_account_id", unique: true
    t.index ["token"], name: "index_aikotoba_account_recovery_tokens_on_token", unique: true
  end

  create_table "aikotoba_account_refresh_tokens", force: :cascade do |t|
    t.integer "aikotoba_account_session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expired_at", precision: nil, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["aikotoba_account_session_id"], name: "idx_aikotoba_refresh_tokens_on_session_id", unique: true
    t.index ["expired_at"], name: "index_aikotoba_account_refresh_tokens_on_expired_at"
    t.index ["token"], name: "index_aikotoba_account_refresh_tokens_on_token", unique: true
  end

  create_table "aikotoba_account_sessions", force: :cascade do |t|
    t.integer "aikotoba_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expired_at", precision: nil, null: false
    t.string "ip_address"
    t.string "origin", default: "browser", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["aikotoba_account_id"], name: "index_aikotoba_account_sessions_on_aikotoba_account_id"
    t.index ["token"], name: "index_aikotoba_account_sessions_on_token", unique: true
  end

  create_table "aikotoba_account_unlock_tokens", force: :cascade do |t|
    t.integer "aikotoba_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expired_at", precision: nil, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["aikotoba_account_id"], name: "index_account_unlock_tokens_on_account_id", unique: true
    t.index ["token"], name: "index_aikotoba_account_unlock_tokens_on_token", unique: true
  end

  create_table "aikotoba_accounts", force: :cascade do |t|
    t.integer "authenticate_target_id"
    t.string "authenticate_target_type"
    t.boolean "confirmed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.boolean "locked", default: false, null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["authenticate_target_type", "authenticate_target_id"], name: "index_aikotoba_accounts_on_authenticate_target", unique: true
    t.index ["email"], name: "index_aikotoba_accounts_on_email", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nickname"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "aikotoba_account_confirmation_tokens", "aikotoba_accounts"
  add_foreign_key "aikotoba_account_recovery_tokens", "aikotoba_accounts"
  add_foreign_key "aikotoba_account_refresh_tokens", "aikotoba_account_sessions"
  add_foreign_key "aikotoba_account_sessions", "aikotoba_accounts"
  add_foreign_key "aikotoba_account_unlock_tokens", "aikotoba_accounts"
end
