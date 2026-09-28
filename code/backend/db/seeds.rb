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

# 職種（大分類の中に中分類）。code をキーにする（その他決め事.md の 5-7）。
# 設計書の表にある読み仮名（「DX（ディーエックス）」など）は、設計書を読む人のためのものなので、データには入れない
[
  {
    code: "1", name: "Web・アプリ開発", description: "Webサービスやスマホアプリなど、利用者が触るソフトウェアを作る",
    middles: [
      { code: "1-1", name: "フロントエンド", description: "Webサービスの画面など、目に見える部分を作る" },
      { code: "1-2", name: "バックエンド", description: "ログインやデータ保存など、裏側の仕組みを作る" },
      { code: "1-3", name: "フルスタック", description: "画面と裏側の両方を担当する" },
      { code: "1-4", name: "スマホアプリ", description: "iPhoneやAndroidのアプリを作る" },
      { code: "1-5", name: "業務システム・DX", description: "企業の仕事を効率化するシステムを作る" },
      { code: "1-6", name: "ゲーム・XR", description: "ゲームやVR・ARのコンテンツを作る" },
      { code: "1-7", name: "組み込み・IoT", description: "家電や機械の中で動くプログラムを作る" }
    ]
  },
  {
    code: "2", name: "AI・データ", description: "AIの開発やデータの分析を行う",
    middles: [
      { code: "2-1", name: "生成AI・LLM", description: "ChatGPTのような生成AIを使った機能を作る" },
      { code: "2-2", name: "機械学習", description: "画像認識や予測などのAIモデルを作る" },
      { code: "2-3", name: "データ分析", description: "データを分析して、グラフや改善提案にまとめる" },
      { code: "2-4", name: "データ基盤", description: "分析に使うデータを集めて整える仕組みを作る" },
      { code: "2-5", name: "AI研究・論文実装", description: "最新の論文を読み、新しい手法を試す" }
    ]
  },
  {
    code: "3", name: "インフラ・クラウド", description: "サービスを動かす土台（サーバーやネットワーク）を作って守る",
    middles: [
      { code: "3-1", name: "クラウド構築", description: "AWSなどのクラウド上にサーバー環境を作る" },
      { code: "3-2", name: "運用・信頼性向上", description: "サービスが止まらないよう監視し、改善する" },
      { code: "3-3", name: "開発環境・自動化", description: "テストや公開を自動で行う仕組みを作る" },
      { code: "3-4", name: "ネットワーク", description: "通信環境を作って管理する" }
    ]
  },
  {
    code: "4", name: "その他の技術職", description: "品質保証、セキュリティ、研究開発、企画など",
    middles: [
      { code: "4-1", name: "品質保証・テスト", description: "不具合がないか確認し、テストを自動化する" },
      { code: "4-2", name: "セキュリティ", description: "サービスや社内の安全を守る" },
      { code: "4-3", name: "研究開発", description: "ロボットやハードウェアなどの研究開発" },
      { code: "4-4", name: "企画・PdM", description: "何を作るかを決めて、開発を前に進める" },
      { code: "4-5", name: "社内IT・技術サポート", description: "社内のIT環境の整備や、技術的な問い合わせ対応" }
    ]
  }
].each.with_index(1) do |major_row, major_position|
  major = JobMajorCategory.find_or_initialize_by(code: major_row[:code])
  major.update!(name: major_row[:name], description: major_row[:description], position: major_position)

  # 中分類の表示順は、大分類の中での順
  major_row[:middles].each.with_index(1) do |middle_row, middle_position|
    JobMiddleCategory.find_or_initialize_by(code: middle_row[:code]).update!(
      job_major_category: major,
      name: middle_row[:name],
      description: middle_row[:description],
      position: middle_position
    )
  end
end

# 技術（言語・フレームワーク・技術）。区分ごとに、よく使われるものを上に並べる。
# 並びがそのまま表示順（1〜52）になる（その他決め事.md の 5-8）
technologies_by_category = {
  language: %w[JavaScript TypeScript Python Ruby PHP Java Go Kotlin Swift Dart C C++ C# Rust Scala R SQL],
  framework: [
    "React", "Next.js", "Vue.js", "Nuxt", "Angular", "Ruby on Rails", "Django", "FastAPI", "Flask", "Laravel",
    "Spring Boot", "Express", "NestJS", "Flutter", "React Native", "Unity", "Unreal Engine", "PyTorch", "TensorFlow"
  ],
  cloud: [ "AWS", "Google Cloud", "Microsoft Azure", "Firebase", "Vercel" ],
  other: [
    "Docker", "Kubernetes", "Terraform", "Git", "GitHub Actions", "PostgreSQL", "MySQL", "MongoDB", "Redis",
    "Linux", "Figma"
  ]
}
technologies = technologies_by_category.flat_map { |category, names| names.map { |name| [ category, name ] } }
technologies.each.with_index(1) do |(category, name), position|
  Technology.find_or_initialize_by(name: name).update!(category: category, position: position)
end

# 工程。上流 → 中流 → 下流の順に並べ、並びがそのまま表示順（1〜13）になる（その他決め事.md の 5-8）
[
  # 上流
  "企画・要件定義",
  "設計",
  "課題設定",
  "テスト計画・リスク評価",
  # 中流
  "実装",
  "構築・自動化",
  "データ収集・整備",
  "分析・モデル開発・実験",
  # 下流
  "テスト・評価",
  "リリース・本番導入",
  "運用・改善",
  "監視・障害対応",
  "発表・論文化"
].each.with_index(1) do |name, position|
  WorkProcess.find_or_initialize_by(name: name).update!(position: position)
end

# 都道府県。id に JIS コードを指定して入れる（データベース.md の 8-5）。並びがそのまま番号になる
%w[
  北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県
  茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県
  新潟県 富山県 石川県 福井県 山梨県 長野県
  岐阜県 静岡県 愛知県 三重県
  滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県
  鳥取県 島根県 岡山県 広島県 山口県
  徳島県 香川県 愛媛県 高知県
  福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県
].each.with_index(1) do |name, id|
  Prefecture.find_or_initialize_by(id: id).update!(name: name)
end

# 大学。デモ用に代表的な20校を仮置きする（データベース.md の 8-5）。
# 学校コードは文部科学省の学校コード一覧（令和8年5月1日時点）の値。学校コードをキーにして、あれば名前を更新、なければ作る。
# 表示は学校コードの順（University.ordered）なので、ここの並びは表示順に関係しない
[
  %w[F101110100010 北海道大学],
  %w[F104110100856 東北大学],
  %w[F108110101423 筑波大学],
  %w[F113110102700 東京大学],
  %w[F113110112030 東京科学大学],
  %w[F113110102791 一橋大学],
  %w[F123110106429 名古屋大学],
  %w[F126110107407 京都大学],
  %w[F127110107852 大阪大学],
  %w[F128110108654 神戸大学],
  %w[F140110110592 九州大学],
  %w[F113210102824 東京都立大学],
  %w[F127210111989 大阪公立大学],
  %w[F113310103581 早稲田大学],
  %w[F113310102984 慶應義塾大学],
  %w[F113310103064 上智大学],
  %w[F113310103340 東京理科大学],
  %w[F113310103536 明治大学],
  %w[F126310107617 立命館大学],
  %w[F126310107564 同志社大学]
].each do |school_code, name|
  University.find_or_initialize_by(school_code: school_code).update!(name: name)
end

# 学部と、その中の学科（仮データ。データベース.md の 8-5）。並びがそのまま表示順になる。
# どの学部にも「その他」の学科を入れる（ページ設計.md の 6-6 S1）
{
  "工学部" => %w[情報工学科 機械工学科 電気電子工学科 建築学科 その他],
  "理学部" => %w[数学科 物理学科 化学科 生物学科 その他],
  "情報学部" => %w[情報科学科 情報システム学科 情報メディア学科 その他],
  "文学部" => %w[日本文学科 英米文学科 史学科 心理学科 その他],
  "経済学部" => %w[経済学科 経営学科 その他],
  "その他" => %w[その他]
}.each.with_index(1) do |(faculty_name, department_names), faculty_position|
  faculty = Faculty.find_or_initialize_by(name: faculty_name)
  faculty.update!(position: faculty_position)
  department_names.each.with_index(1) do |department_name, department_position|
    Department.find_or_initialize_by(faculty: faculty, name: department_name).update!(position: department_position)
  end
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
student_profile = student_user.student_profile ||
                  student_user.create_student_profile!(name: "山田 花子", activity_status: :skill_up)
# 活動状況は必須（その他決め事.md の 5-9）。順3 より前に作った試しの学生は空なので、空なら入れる
student_profile.update!(activity_status: :skill_up) if student_profile.activity_status.nil?

# ── 推薦の集計 ──

# 試しのアカウントは新規登録の処理を通らずに作るので、推薦の集計の行ができない。
# 全体の作り直しをその場で実行して作る（処理設計_類似度.md の 7-5。順12）。何度実行しても同じ結果になる
RecommendationStatsRebuildJob.perform_now
