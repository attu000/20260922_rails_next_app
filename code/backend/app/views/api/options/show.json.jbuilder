# ⑦ GET /api/options の形（design/designs/API設計.md の 16-3 ⑦）。
# 順1〜順5 で使う選択肢とマスタだけを返す。ほかの項目（工程、性格・カルチャーの5軸など）は、使う順で足す（未決内容.md の 11-2）。
# 選択肢の値はモデルの enum の名前、表示名は config/locales/ja.yml から取る

json.enums do
  # 人数
  json.employee_size CompanyProfile.employee_sizes.keys do |value|
    json.value value
    json.label t("enums.company_profile.employee_size.#{value}")
  end
  # 募集状態
  json.job_posting_status JobPosting.statuses.keys do |value|
    json.value value
    json.label t("enums.job_posting.status.#{value}")
  end
  # 勤務形態
  json.work_style JobPosting.work_styles.keys do |value|
    json.value value
    json.label t("enums.job_posting.work_style.#{value}")
  end
  # 技術の区分
  json.technology_category Technology.categories.keys do |value|
    json.value value
    json.label t("enums.technology.category.#{value}")
  end
  # 学年
  json.grade StudentProfile.grades.keys do |value|
    json.value value
    json.label t("enums.student_profile.grade.#{value}")
  end
  # 活動状況
  json.activity_status StudentProfile.activity_statuses.keys do |value|
    json.value value
    json.label t("enums.student_profile.activity_status.#{value}")
  end
  # プログラミング歴のレベル
  json.skill_level StudentSkill.levels.keys do |value|
    json.value value
    json.label t("enums.student_skill.level.#{value}")
  end
  # 応募理由・マッチ理由（12個。画面に出す順。app/models/candidacy_reason.rb）
  json.candidacy_reason CandidacyReason.reasons.keys do |value|
    json.value value
    json.label t("enums.candidacy_reason.reason.#{value}")
  end
  # 学生から見た、募集とのやりとりの状態
  json.my_status Candidacy::MY_STATUSES do |value|
    json.value value
    json.label t("enums.candidacy.my_status.#{value}")
  end
end

# 稼働条件の数値の選択肢。Rails の検証と同じ定数から作る（app/models/concerns/work_conditions.rb）
json.work_conditions do
  json.work_days_per_week WorkConditions::WORK_DAYS_PER_WEEK
  json.work_hours_per_day WorkConditions::WORK_HOURS_PER_DAY
  json.duration_months WorkConditions::DURATION_MONTHS
end

json.masters do
  # 職種。大分類の中に中分類を入れる（中分類は表示順。app/models/job_major_category.rb）
  json.job_major_categories @job_major_categories do |major|
    json.extract! major, :id, :code, :name, :description
    json.job_middle_categories major.job_middle_categories, :id, :code, :name, :description
  end
  json.technologies @technologies, :id, :name, :category
  json.industries @industries, :id, :name
  json.business_types @business_types, :id, :name
  json.prefectures @prefectures, :id, :name
  # 大学（学校コードの順。app/models/university.rb）
  json.universities @universities, :id, :name
  # 学部。中に学科を入れる（学科は学部の中での表示順。app/models/faculty.rb）
  json.faculties @faculties do |faculty|
    json.extract! faculty, :id, :name
    json.departments faculty.departments, :id, :name
  end
end
