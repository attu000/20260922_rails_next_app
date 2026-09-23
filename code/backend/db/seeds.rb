# 試しのデータ。bin/rails db:seed で入れる（Django の loaddata にあたる）。
# 何度実行しても同じ結果になるよう、すでにあれば作らない。
# 新規登録の画面は Phase 6 で作るので、それまではこのアカウントでログインを試す（design/designs/未決内容.md の 11-2）

# 企業のアカウント
company_user = User.find_or_create_by!(email: "company@example.com") do |user|
  user.password = "password"
  user.role = :company
end
company_user.company_profile || company_user.create_company_profile!(name: "株式会社サンプル")

# 学生のアカウント
student_user = User.find_or_create_by!(email: "student@example.com") do |user|
  user.password = "password"
  user.role = :student
end
student_user.student_profile || student_user.create_student_profile!(name: "山田 花子")
