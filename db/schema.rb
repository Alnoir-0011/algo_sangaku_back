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

ActiveRecord::Schema[8.0].define(version: 2025_05_27_062857) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "fixed_inputs", force: :cascade do |t|
    t.text "content", null: false
    t.bigint "sangaku_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content", "sangaku_id"], name: "index_fixed_inputs_on_content_and_sangaku_id", unique: true
    t.index ["sangaku_id"], name: "index_fixed_inputs_on_sangaku_id"
  end

  create_table "sangakus", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.text "source", null: false
    t.integer "difficulty", default: 0, null: false
    t.bigint "user_id", null: false
    t.bigint "shrine_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shrine_id"], name: "index_sangakus_on_shrine_id"
    t.index ["user_id"], name: "index_sangakus_on_user_id"
  end

  create_table "shrines", force: :cascade do |t|
    t.string "name", null: false
    t.string "address", null: false
    t.float "latitude", null: false
    t.float "longitude", null: false
    t.string "place_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["place_id"], name: "index_shrines_on_place_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "nickname", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "fixed_inputs", "sangakus"
  add_foreign_key "sangakus", "shrines"
  add_foreign_key "sangakus", "users"
end
