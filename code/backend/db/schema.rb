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

ActiveRecord::Schema[8.1].define(version: 2026_09_25_130007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "business_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_business_types_on_name", unique: true
  end

  create_table "company_business_types", force: :cascade do |t|
    t.bigint "business_type_id", null: false
    t.bigint "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_type_id"], name: "index_company_business_types_on_business_type_id"
    t.index ["company_profile_id", "business_type_id"], name: "idx_on_company_profile_id_business_type_id_c16839bc34", unique: true
    t.index ["company_profile_id"], name: "index_company_business_types_on_company_profile_id"
  end

  create_table "company_industries", force: :cascade do |t|
    t.bigint "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.bigint "industry_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_profile_id", "industry_id"], name: "index_company_industries_on_company_profile_id_and_industry_id", unique: true
    t.index ["company_profile_id"], name: "index_company_industries_on_company_profile_id"
    t.index ["industry_id"], name: "index_company_industries_on_industry_id"
  end

  create_table "company_profiles", force: :cascade do |t|
    t.text "about"
    t.text "business_description"
    t.datetime "created_at", null: false
    t.integer "employee_size"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_company_profiles_on_user_id", unique: true
  end

  create_table "industries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_industries_on_name", unique: true
  end

  create_table "job_major_categories", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_job_major_categories_on_code", unique: true
  end

  create_table "job_middle_categories", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.bigint "job_major_category_id", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_job_middle_categories_on_code", unique: true
    t.index ["job_major_category_id"], name: "index_job_middle_categories_on_job_major_category_id"
  end

  create_table "job_posting_job_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_middle_category_id", null: false
    t.bigint "job_posting_id", null: false
    t.integer "role", null: false
    t.datetime "updated_at", null: false
    t.index ["job_middle_category_id"], name: "index_job_posting_job_categories_on_job_middle_category_id"
    t.index ["job_posting_id", "job_middle_category_id"], name: "idx_on_job_posting_id_job_middle_category_id_ff30f932c4", unique: true
    t.index ["job_posting_id"], name: "index_job_posting_job_categories_on_job_posting_id"
  end

  create_table "job_posting_technologies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_posting_id", null: false
    t.bigint "technology_id", null: false
    t.datetime "updated_at", null: false
    t.index ["job_posting_id", "technology_id"], name: "idx_on_job_posting_id_technology_id_5944876302", unique: true
    t.index ["job_posting_id"], name: "index_job_posting_technologies_on_job_posting_id"
    t.index ["technology_id"], name: "index_job_posting_technologies_on_technology_id"
  end

  create_table "job_postings", force: :cascade do |t|
    t.text "about"
    t.text "business_description"
    t.bigint "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.text "growth"
    t.integer "hourly_wage"
    t.text "internship_details"
    t.integer "min_duration_months", limit: 2
    t.integer "min_work_days_per_week", limit: 2
    t.integer "min_work_hours_per_day", limit: 2
    t.bigint "prefecture_id"
    t.text "preferred_requirements"
    t.datetime "published_at"
    t.text "requirements"
    t.date "start_month"
    t.integer "status", default: 0, null: false
    t.text "technology_note"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.boolean "weekend_ok", default: false, null: false
    t.string "work_location_note"
    t.text "work_note"
    t.integer "work_style"
    t.string "work_style_note"
    t.index ["company_profile_id"], name: "index_job_postings_on_company_profile_id"
    t.index ["prefecture_id"], name: "index_job_postings_on_prefecture_id"
    t.index ["status", "published_at"], name: "index_job_postings_on_status_and_published_at"
    t.check_constraint "hourly_wage > 0", name: "job_postings_hourly_wage_positive"
    t.check_constraint "status <> 1 OR internship_details IS NOT NULL AND hourly_wage IS NOT NULL", name: "job_postings_published_requires_details"
  end

  create_table "prefectures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "student_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_student_profiles_on_user_id", unique: true
  end

  create_table "technologies", force: :cascade do |t|
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_technologies_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.date "last_active_on"
    t.string "password_digest", null: false
    t.integer "role", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "company_business_types", "business_types"
  add_foreign_key "company_business_types", "company_profiles"
  add_foreign_key "company_industries", "company_profiles"
  add_foreign_key "company_industries", "industries"
  add_foreign_key "company_profiles", "users"
  add_foreign_key "job_middle_categories", "job_major_categories"
  add_foreign_key "job_posting_job_categories", "job_middle_categories"
  add_foreign_key "job_posting_job_categories", "job_postings"
  add_foreign_key "job_posting_technologies", "job_postings"
  add_foreign_key "job_posting_technologies", "technologies"
  add_foreign_key "job_postings", "company_profiles"
  add_foreign_key "job_postings", "prefectures"
  add_foreign_key "sessions", "users"
  add_foreign_key "student_profiles", "users"
end
