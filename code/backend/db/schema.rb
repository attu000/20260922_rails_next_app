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

ActiveRecord::Schema[8.1].define(version: 2026_09_26_120003) do
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

  create_table "candidacies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_posting_id", null: false
    t.datetime "matched_at"
    t.integer "origin", null: false
    t.integer "reason_mask", limit: 2
    t.integer "status", default: 0, null: false
    t.bigint "student_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["job_posting_id", "status"], name: "index_candidacies_on_job_posting_id_and_status"
    t.index ["job_posting_id", "student_profile_id"], name: "index_candidacies_on_job_posting_id_and_student_profile_id", unique: true
    t.index ["job_posting_id"], name: "index_candidacies_on_job_posting_id"
    t.index ["job_posting_id"], name: "index_candidacies_on_job_posting_id_with_reasons", where: "(reason_mask IS NOT NULL)"
    t.index ["student_profile_id"], name: "index_candidacies_on_student_profile_id"
    t.index ["student_profile_id"], name: "index_candidacies_on_student_profile_id_with_reasons", where: "(reason_mask IS NOT NULL)"
    t.check_constraint "reason_mask >= 1 AND reason_mask <= 4095", name: "candidacies_reason_mask_range"
  end

  create_table "candidacy_reasons", force: :cascade do |t|
    t.bigint "candidacy_id", null: false
    t.datetime "created_at", null: false
    t.integer "reason", null: false
    t.datetime "updated_at", null: false
    t.index ["candidacy_id", "reason"], name: "index_candidacy_reasons_on_candidacy_id_and_reason", unique: true
    t.index ["candidacy_id"], name: "index_candidacy_reasons_on_candidacy_id"
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

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "faculty_id", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["faculty_id", "name"], name: "index_departments_on_faculty_id_and_name", unique: true
    t.index ["faculty_id"], name: "index_departments_on_faculty_id"
  end

  create_table "faculties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_faculties_on_name", unique: true
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

  create_table "message_threads", force: :cascade do |t|
    t.bigint "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_message_at"
    t.bigint "student_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_profile_id", "student_profile_id"], name: "idx_on_company_profile_id_student_profile_id_acbd6009bb", unique: true
    t.index ["company_profile_id"], name: "index_message_threads_on_company_profile_id"
    t.index ["student_profile_id"], name: "index_message_threads_on_student_profile_id"
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

  create_table "student_commutable_prefectures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "prefecture_id", null: false
    t.bigint "student_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["prefecture_id"], name: "index_student_commutable_prefectures_on_prefecture_id"
    t.index ["student_profile_id", "prefecture_id"], name: "idx_on_student_profile_id_prefecture_id_da0300621b", unique: true
    t.index ["student_profile_id"], name: "index_student_commutable_prefectures_on_student_profile_id"
  end

  create_table "student_interested_job_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_middle_category_id", null: false
    t.bigint "student_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["job_middle_category_id"], name: "idx_on_job_middle_category_id_62e136b596"
    t.index ["student_profile_id", "job_middle_category_id"], name: "idx_on_student_profile_id_job_middle_category_id_2286816a98", unique: true
    t.index ["student_profile_id"], name: "index_student_interested_job_categories_on_student_profile_id"
  end

  create_table "student_profiles", force: :cascade do |t|
    t.integer "activity_status"
    t.date "available_from"
    t.boolean "can_full_remote", default: true, null: false
    t.boolean "can_onsite", default: true, null: false
    t.boolean "can_partial_remote", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "department_id"
    t.integer "duration_months", limit: 2
    t.bigint "faculty_id"
    t.integer "grade"
    t.integer "graduation_year"
    t.string "name", null: false
    t.bigint "prefecture_id"
    t.text "self_pr_future"
    t.text "self_pr_strength"
    t.text "self_pr_weakness"
    t.bigint "university_id"
    t.string "university_other_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "work_days_per_week", limit: 2
    t.integer "work_hours_per_day", limit: 2
    t.text "work_note"
    t.index ["department_id"], name: "index_student_profiles_on_department_id"
    t.index ["faculty_id"], name: "index_student_profiles_on_faculty_id"
    t.index ["prefecture_id"], name: "index_student_profiles_on_prefecture_id"
    t.index ["university_id"], name: "index_student_profiles_on_university_id"
    t.index ["user_id"], name: "index_student_profiles_on_user_id", unique: true
    t.check_constraint "university_id IS NULL OR university_other_name IS NULL", name: "student_profiles_university_or_other_name"
  end

  create_table "student_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "level", null: false
    t.string "other_name"
    t.bigint "student_profile_id", null: false
    t.bigint "technology_id"
    t.datetime "updated_at", null: false
    t.decimal "years", precision: 3, scale: 1
    t.index ["student_profile_id", "technology_id"], name: "index_student_skills_on_student_profile_id_and_technology_id", unique: true
    t.index ["student_profile_id"], name: "index_student_skills_on_student_profile_id"
    t.index ["technology_id"], name: "index_student_skills_on_technology_id"
    t.check_constraint "(technology_id IS NULL) <> (other_name IS NULL)", name: "student_skills_technology_or_other_name"
  end

  create_table "technologies", force: :cascade do |t|
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_technologies_on_name", unique: true
  end

  create_table "universities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "school_code", null: false
    t.datetime "updated_at", null: false
    t.index ["school_code"], name: "index_universities_on_school_code", unique: true
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
  add_foreign_key "candidacies", "job_postings"
  add_foreign_key "candidacies", "student_profiles"
  add_foreign_key "candidacy_reasons", "candidacies"
  add_foreign_key "company_business_types", "business_types"
  add_foreign_key "company_business_types", "company_profiles"
  add_foreign_key "company_industries", "company_profiles"
  add_foreign_key "company_industries", "industries"
  add_foreign_key "company_profiles", "users"
  add_foreign_key "departments", "faculties"
  add_foreign_key "job_middle_categories", "job_major_categories"
  add_foreign_key "job_posting_job_categories", "job_middle_categories"
  add_foreign_key "job_posting_job_categories", "job_postings"
  add_foreign_key "job_posting_technologies", "job_postings"
  add_foreign_key "job_posting_technologies", "technologies"
  add_foreign_key "job_postings", "company_profiles"
  add_foreign_key "job_postings", "prefectures"
  add_foreign_key "message_threads", "company_profiles"
  add_foreign_key "message_threads", "student_profiles"
  add_foreign_key "sessions", "users"
  add_foreign_key "student_commutable_prefectures", "prefectures"
  add_foreign_key "student_commutable_prefectures", "student_profiles"
  add_foreign_key "student_interested_job_categories", "job_middle_categories"
  add_foreign_key "student_interested_job_categories", "student_profiles"
  add_foreign_key "student_profiles", "departments"
  add_foreign_key "student_profiles", "faculties"
  add_foreign_key "student_profiles", "prefectures"
  add_foreign_key "student_profiles", "universities"
  add_foreign_key "student_profiles", "users"
  add_foreign_key "student_skills", "student_profiles"
  add_foreign_key "student_skills", "technologies"
end
