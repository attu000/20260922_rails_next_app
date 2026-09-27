# テスト用のマスタを作るひな形。テストのデータベースには seed が入らないので、使うマスタはテストの中で作る。
# create(:industry) のように使う
FactoryBot.define do
  factory :industry do
    sequence(:name) { |n| "業界#{n}" }
    sequence(:position) { |n| n }
  end

  factory :business_type do
    sequence(:name) { |n| "事業形態#{n}" }
    sequence(:position) { |n| n }
  end

  factory :job_major_category do
    sequence(:code) { |n| "M#{n}" }
    sequence(:name) { |n| "大分類#{n}" }
    description { "大分類の説明" }
    sequence(:position) { |n| n }
  end

  # 中分類。大分類も一緒に作る
  factory :job_middle_category do
    job_major_category
    sequence(:code) { |n| "M-#{n}" }
    sequence(:name) { |n| "中分類#{n}" }
    description { "中分類の説明" }
    sequence(:position) { |n| n }
  end

  factory :work_process do
    sequence(:name) { |n| "工程#{n}" }
    planning { false }
    sequence(:position) { |n| n }
  end

  factory :technology do
    sequence(:name) { |n| "技術#{n}" }
    category { :language }
    sequence(:position) { |n| n }
  end

  factory :prefecture do
    sequence(:name) { |n| "県#{n}" }
  end

  factory :university do
    sequence(:school_code) { |n| format("F1%011d", n) }
    sequence(:name) { |n| "大学#{n}" }
  end

  factory :faculty do
    sequence(:name) { |n| "学部#{n}" }
    sequence(:position) { |n| n }
  end

  # 学科。学部も一緒に作る
  factory :department do
    faculty
    sequence(:name) { |n| "学科#{n}" }
    sequence(:position) { |n| n }
  end
end
