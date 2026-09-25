# テスト用のアカウントを作るひな形。テストの中で create(:company_user) のように使う。
# プロフィールも一緒に作る（本番では新規登録の処理が、アカウントとプロフィールを1つのトランザクションで作る。技術構成.md の 9-2）
FactoryBot.define do
  factory :company_user, class: "User" do
    # 企業と学生で連番が別々に進むので、頭の文字を変えて重ならないようにする
    sequence(:email) { |n| "company#{n}@example.com" }
    password { "password" }
    role { :company }

    after(:create) do |user|
      user.create_company_profile!(name: "株式会社テスト")
    end
  end

  factory :student_user, class: "User" do
    sequence(:email) { |n| "student#{n}@example.com" }
    password { "password" }
    role { :student }

    after(:create) do |user|
      # 活動状況は必須（その他決め事.md の 5-9）
      user.create_student_profile!(name: "テスト 太郎", activity_status: :skill_up)
    end
  end
end
