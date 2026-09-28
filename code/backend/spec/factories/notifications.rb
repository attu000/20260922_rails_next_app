# テスト用の通知を作るひな形。
# create(:notification) で「企業のアカウント宛てに、学生1人についての『おすすめの学生』の通知」を1件作る（未読）
FactoryBot.define do
  factory :notification do
    user { create(:company_user) }
    student_profile { create(:student_user).student_profile }
    kind { :recommended_student }
    body { "自社サービスのバックエンド開発インターンに合いそうな学生がいます" }
    link_path { "/company/students/#{student_profile.id}" }
  end
end
