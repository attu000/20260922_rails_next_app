# 試しのデータ。bin/rails db:seed で入れる（Django の loaddata にあたる）。
# 何度実行しても同じ結果になるよう、すでにあれば作らない。
# 新規登録の画面は Phase 6 で作るので、それまではこのアカウントでログインを試す（design/designs/未決内容.md の 11-2）

# ── マスタ ──
# 名前をキーにして「あれば表示順を更新、なければ作る」。並びがそのまま表示順になる。
# マスタは削除しない（design/designs/技術構成.md の 9-1）。中身は仮置き（その他決め事.md の 5-8、未決内容.md の 10-1）

# 業界（事業分野）
[
  "EC・小売",
  "金融・保険",
  "医療・ヘルスケア・介護",
  "教育",
  "ゲーム",
  "エンタメ・メディア",
  "広告・マーケティング",
  "人材・HR",
  "不動産・建設",
  "製造・ものづくり",
  "物流・交通・モビリティ",
  "旅行・飲食・生活サービス",
  "行政・公共",
  "業界を問わない業務ツール",
  "その他"
].each.with_index(1) do |name, position|
  Industry.find_or_initialize_by(name: name).update!(position: position)
end

# 事業形態
[
  "自社サービス（個人向け）",
  "自社サービス（法人向け）",
  "受託開発・SIer",
  "社内システム"
].each.with_index(1) do |name, position|
  BusinessType.find_or_initialize_by(name: name).update!(position: position)
end

# ── 試しのアカウント ──

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
