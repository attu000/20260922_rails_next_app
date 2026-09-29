# 学生プロフィール（design/designs/データベース.md の 8-5）。
# 必須は氏名と活動状況だけで、マイページでも新規登録でも同じ（その他決め事.md の 5-9）。
# 外部リンク・資格・就活希望エリアは【仕上げ】の順17 で足した（興味のある業界は、学生詳細の比較に使うので順10 で前倒しした。PR254）
class StudentProfile < ApplicationRecord
  # 稼働条件の選択肢と検証。募集と共通（concerns/work_conditions.rb）
  include WorkConditions
  # 働き方の好み（性格）の5軸。募集のカルチャーと共通（concerns/culture_axes.rb）
  include CultureAxes
  # 番号の確認（validate_master_ids・validate_master_id）。企業プロフィール・募集と共通（concerns/master_ids_validation.rb）
  include MasterIdsValidation
  # アイコンの添付と検証（形式・2MB）。企業プロフィールと共通（concerns/icon_attachment.rb）
  include IconAttachment

  # プログラミング歴・外部リンク・資格の件数の上限（権限_バリデーション.md の 17-3-4）
  SKILLS_MAX = 50
  LINKS_MAX = 20
  CERTIFICATIONS_MAX = 50
  # 最終活動日からこの日数以内なら「最近活動した学生」とする（その他決め事.md の 5-4）。
  # ちょうど30日前も含める。企業に見せる最終活動の目安の「30日以内」とそろえるため（PR216）
  ACTIVE_WITHIN_DAYS = 30
  # 企業に見せる最終活動の目安（その他決め事.md の 5-4、API設計.md の形C）。目安の名前 => 最終活動日から今日までの日数の上限。
  # 上から順に当てはめ、どれにも入らなければ over_30_days（30日より前）。ちょうど3日前は「3日以内」に入れる
  LAST_ACTIVE_RANGES = {
    "within_3_days" => 3,
    "within_7_days" => 7,
    "within_30_days" => ACTIVE_WITHIN_DAYS
  }.freeze
  # ⑦ の選択肢（last_active_range）に使う、目安の名前の一覧
  LAST_ACTIVE_RANGE_VALUES = [ *LAST_ACTIVE_RANGES.keys, "over_30_days" ].freeze

  belongs_to :user
  # 大学・学部・学科・在住の都道府県（どれも任意）
  belongs_to :university, optional: true
  belongs_to :faculty, optional: true
  belongs_to :department, optional: true
  belongs_to :prefecture, optional: true

  # プログラミング歴・外部リンク・資格。送られた順のまま返すため、作った順（id の順）に並べる
  has_many :student_skills, -> { order(:id) }
  has_many :student_links, -> { order(:id) }
  has_many :student_certifications, -> { order(:id) }
  # 興味のある職種・興味のある業界・出社できる都道府県・就活希望エリア。Django の ManyToManyField(through=...) にあたる。
  # through を書くと、interested_job_middle_category_ids・interested_industry_ids・commutable_prefecture_ids・
  # job_hunting_prefecture_ids が自動でできる
  has_many :student_interested_job_categories
  has_many :interested_job_middle_categories, through: :student_interested_job_categories, source: :job_middle_category
  has_many :student_interested_industries
  has_many :interested_industries, through: :student_interested_industries, source: :industry
  has_many :student_commutable_prefectures
  has_many :commutable_prefectures, through: :student_commutable_prefectures, source: :prefecture
  has_many :student_job_hunting_prefectures
  has_many :job_hunting_prefectures, through: :student_job_hunting_prefectures, source: :prefecture
  # 自分のやりとり（応募・スカウト）と、企業とのスレッド。窓口では、自分の分の中からだけ番号で探す（API設計.md の 16-1-10）
  has_many :candidacies
  has_many :message_threads
  # 推薦の集計の行（1人1行）。student_profile.recommendation_stat で取り出す。Django の OneToOneField の逆向きの参照にあたる
  has_one :recommendation_stat, class_name: "StudentRecommendationStat"

  # 学年と活動状況。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。範囲外の値は検証エラーにする
  enum :grade, {
    undergrad_1: 0,
    undergrad_2: 1,
    undergrad_3: 2,
    undergrad_4: 3,
    undergrad_5_plus: 4,
    master_1: 5,
    master_2: 6,
    doctoral: 7,
    kosen: 8,
    other: 9
  }, validate: { allow_nil: true }
  enum :activity_status, {
    not_looking: 0,
    skill_up: 1,
    job_hunting: 2
  }, validate: { allow_nil: true }

  # 最近（30日以内に）活動した学生。学生検索（C5）の対象で、後で「似た学生」と通知でも使う（その他決め事.md の 5-4）。
  # 最終活動日が空欄の学生（一度もログインしていない）は、活動の記録がないので入らない（PR216）。
  # ログイン情報（users）の表を結合せず「番号がこの一覧に入っているか」（サブクエリ）で絞る。
  # 結合すると、検索で条件を and でつなぐときに「形の違う絞り込み」として Rails に拒まれるため
  scope :recently_active, lambda {
    where(user_id: User.where(last_active_on: (Time.zone.today - ACTIVE_WITHIN_DAYS)..).select(:id))
  }

  # 任意の文章が空白だけで送られてきたら、空欄（null）にそろえて保存する。
  # 大学名（その他）は、空白だけで一覧の大学との CHECK をすり抜けないようにするためでもある
  normalizes :university_other_name, :self_pr_strength, :self_pr_weakness, :self_pr_future, :work_note,
             with: ->(value) { value.presence }

  # 形式と長さの決まり（権限_バリデーション.md の 17-3-4）
  validates :name, presence: true, length: { maximum: 100 }
  validates :activity_status, presence: true
  validates :university_other_name, length: { maximum: 100 }
  validates :self_pr_strength, :self_pr_weakness, :self_pr_future, :work_note, length: { maximum: 2000 }
  # 卒業年度は整数。範囲の制限はない（画面の選択肢は今年〜10年後）
  validates :graduation_year, numericality: { only_integer: true }, allow_nil: true
  # 稼働条件の3つの数値（選択肢は concerns/work_conditions.rb）
  validates_work_conditions days: :work_days_per_week,
                            hours: :work_hours_per_day,
                            months: :duration_months
  # 働き方の好みの5軸は、−2〜2 の整数（concerns/culture_axes.rb）
  validates_culture_axes :personality
  # 勤務形態の可否は true か false（データベースで空欄不可）
  validates :can_full_remote, :can_partial_remote, :can_onsite, inclusion: { in: [ true, false ] }
  validate :available_from_must_be_first_day
  validate :university_and_other_name_not_both
  validate :department_must_belong_to_selected_faculty
  # 番号1つがマスタにあるか（concerns/master_ids_validation.rb）
  validate do
    validate_master_id(:university_id, university_id, University)
    validate_master_id(:faculty_id, faculty_id, Faculty)
    validate_master_id(:department_id, department_id, Department)
    validate_master_id(:prefecture_id, prefecture_id, Prefecture)
  end

  # エラーの項目名を引くとき、行ごとの付属情報のエラー（skills[0].years・links[0].url・certifications[0].name など）は、
  # 1行分のモデルの項目名を使う。これで「年数は50以下の値にしてください」のような文になる（API設計.md の 16-3 ⑯）。
  # 何もしないと、Rails は skills[0].years という項目名を見つけられず「Skills[0] years は…」になる
  def self.human_attribute_name(attribute, options = {})
    row_name, row_attribute = attribute.to_s.match(/\A(skills|links|certifications)(?:\[\d+\])?\.(.+)\z/)&.captures
    return super if row_name.nil?

    row_model = { "skills" => StudentSkill, "links" => StudentLink, "certifications" => StudentCertification }.fetch(row_name)
    row_model.human_attribute_name(row_attribute, options)
  end

  # 自分が見てよい募集（API設計.md の 16-1-10、16-3 ⑲）。募集詳細と応募の窓口は、ここから番号で探す（範囲の外は 404）。
  # 掲載中の募集と、自分とやりとりがある募集（非公開・終了でも開ける。画面は「募集終了」と出す）。
  # 一度も掲載していない募集にはやりとりができないので、ここには入らない
  def visible_job_postings
    JobPosting.published.or(JobPosting.where(id: candidacies.select(:job_posting_id)))
  end

  # 企業に見せる最終活動の目安（学生検索・似た学生の行と学生詳細。API設計.md の形C・16-3 ㉓）。
  # 日付そのものは見せず、"within_3_days" などの名前を返す。表示名は ⑦ の enums.last_active_range。
  # 最終活動日が空（一度もログインしていない）なら nil（PR335）。「30日より前」と出すと、前は活動していたように読めるため。
  # user を読むので、一覧で使うときは呼ぶ側が includes(:user) でまとめて読んでおく（N+1問題を避ける）。
  # Django のモデルの @property にあたる
  def last_active_range
    last_active_on = user.last_active_on
    return nil if last_active_on.nil?

    days = (Time.zone.today - last_active_on).to_i
    LAST_ACTIVE_RANGES.find { |_range, max_days| days <= max_days }&.first || "over_30_days"
  end

  # 学生プロフィールの保存（⑯ PATCH /api/student/profile）。窓口はこれを呼ぶだけにする（技術構成.md の 9-2）。
  # 保存できたら true、入力に誤りがあれば false を返す（誤りは errors に入る）。
  # 企業プロフィール・募集と同じく、「先に全部確かめてから（assign_profile）、トランザクションの中で書き込む（write_profile!）」順番にしている。
  # 新規登録（StudentRegistration）も、この2つを使ってアカウントと一緒に書き込む（PR226）
  def save_profile(attributes)
    return false unless assign_profile(attributes)

    # まとめて書き込む。途中で失敗したら、すべて取り消す（Django の transaction.atomic() にあたる）
    transaction { write_profile! }
    true
  end

  # 値をモデルに入れて確かめる。まだ何も書き込まない。誤りがなければ true（誤りは errors に入る）。
  # 中間テーブルに書く番号の一覧と、作り直すプログラミング歴・外部リンク・資格は、write_profile! で使うために覚えておく
  def assign_profile(attributes)
    attributes = attributes.to_h.symbolize_keys
    @pending_job_middle_category_ids = attributes.delete(:interested_job_middle_category_ids)
    @pending_industry_ids = attributes.delete(:interested_industry_ids)
    @pending_commutable_prefecture_ids = attributes.delete(:commutable_prefecture_ids)
    @pending_job_hunting_prefecture_ids = attributes.delete(:job_hunting_prefecture_ids)
    skill_rows = attributes.delete(:skills)
    link_rows = attributes.delete(:links)
    certification_names = attributes.delete(:certifications)

    # ① 本体の値を、保存せずにモデルに入れるだけ
    assign_attributes(attributes)

    # ② 検証する。③ 番号の一覧と、プログラミング歴・外部リンク・資格の各行を確かめる
    valid?
    validate_master_ids(:interested_job_middle_category_ids, @pending_job_middle_category_ids, JobMiddleCategory)
    validate_master_ids(:interested_industry_ids, @pending_industry_ids, Industry)
    validate_master_ids(:commutable_prefecture_ids, @pending_commutable_prefecture_ids, Prefecture)
    validate_master_ids(:job_hunting_prefecture_ids, @pending_job_hunting_prefecture_ids, Prefecture)
    @pending_skills = build_skills(skill_rows)
    @pending_links = build_links(link_rows)
    @pending_certifications = build_certifications(certification_names)
    errors.empty?
  end

  # assign_profile で確かめた内容を書き込む。トランザクションの中で呼ぶ。
  # マイページの保存（save_profile）と新規登録（StudentRegistration）の両方がここを通る
  def write_profile!
    save!
    # 中間テーブルを、送られた一覧でまるごと置き換える（16-3 ⑯）。送られなかった項目は変えない
    self.interested_job_middle_category_ids = @pending_job_middle_category_ids unless @pending_job_middle_category_ids.nil?
    self.interested_industry_ids = @pending_industry_ids unless @pending_industry_ids.nil?
    self.commutable_prefecture_ids = @pending_commutable_prefecture_ids unless @pending_commutable_prefecture_ids.nil?
    self.job_hunting_prefecture_ids = @pending_job_hunting_prefecture_ids unless @pending_job_hunting_prefecture_ids.nil?
    # 行ごとの付属情報は、消して作り直す（16-3 ⑯）
    replace_rows(StudentSkill, student_skills, @pending_skills) unless @pending_skills.nil?
    replace_rows(StudentLink, student_links, @pending_links) unless @pending_links.nil?
    replace_rows(StudentCertification, student_certifications, @pending_certifications) unless @pending_certifications.nil?
    # 推薦の集計の項目数を、付属テーブルと同じトランザクションで数え直す（処理設計_類似度.md の 7-5。PR286）。
    # 項目と数が同じ時点で変わらないと、Content の分母がずれるため。新規登録のときは、ここで集計の行ができる（件数と self_weight は0）。
    # どの項目が変わったかは見ずに、毎回数え直す（自分の1行だけなので軽い）
    StudentRecommendationStat.refresh_item_counts!([ id ])
  end

  # エラーの文を作るとき、Rails は項目の今の値を読みに行く（文の中に %{value} で差し込めるようにするため）。
  # プログラミング歴・外部リンク・資格の欄全体のエラーは skills・links・certifications の名前で入れるので、
  # その名前で読めるようにする。
  # alias_method で作ったメソッドは private の指定が効かないので、下の行で外から呼べないようにする
  alias_method :skills, :student_skills
  alias_method :links, :student_links
  alias_method :certifications, :student_certifications
  private :skills, :links, :certifications

  private

  # 開始時期は月の1日の日付。範囲の制限はない（募集と同じ。その他決め事.md の 5-6）
  def available_from_must_be_first_day
    errors.add(:available_from, :invalid) if available_from.present? && available_from.day != 1
  end

  # 一覧の大学と「その他」の名前は、両方同時には入らない（データベースの CHECK でも守る）
  def university_and_other_name_not_both
    errors.add(:university_other_name, :present) if university_id.present? && university_other_name.present?
  end

  # 学科は、選んだ学部のもの。学部を選ばずに学科だけ選んだ場合も、これで止める
  def department_must_belong_to_selected_faculty
    return if department_id.blank?

    department = Department.find_by(id: department_id)
    # 学科そのものがないときは、validate_master_id が「学科は一覧にありません」を出す
    return if department.nil?

    errors.add(:department_id, :not_in_selected_faculty) if department.faculty_id != faculty_id
  end

  # 行ごとの付属情報（プログラミング歴・外部リンク・資格）を、送られた行から作って確かめる（まだ保存しない）。
  # 送られなかったら nil を返す。1行分のモデルは、ブロック（呼ぶ側の do … end）が作る。
  # 行ごとの誤りは skills[0].years のように行の番号を付けた名前で、欄全体の誤りは skills の名前で入れる（API設計.md の 16-3 ⑯）
  def build_rows(name, rows, max)
    return nil if rows.nil?

    rows = Array(rows)
    errors.add(name, :too_many, count: max) if rows.size > max

    rows.each_with_index.map do |row, index|
      record = yield(row)
      record.valid?
      # 1行分の誤りを、行の番号を付けた名前で写す。文（「は50以下の値にしてください」）は1行分のモデルが作ったものを使う
      record.errors.each { |error| errors.import(error, attribute: "#{name}[#{index}].#{error.attribute}") }
      record
    end
  end

  # プログラミング歴。送られるのは { technology_id, other_name, years, level } の行の一覧
  def build_skills(rows)
    skills = build_rows(:skills, rows, SKILLS_MAX) do |row|
      # save_profile の symbolize_keys は外側の名前だけをシンボルにし、中の各行は「名前が文字列の普通の辞書」にしてしまう。
      # row[:technology_id] で取り出せるよう、文字列でもシンボルでも取り出せる形に直す
      row = row.to_h.with_indifferent_access
      StudentSkill.new(student_profile: self, technology_id: row[:technology_id], other_name: row[:other_name],
                       years: row[:years], level: row[:level])
    end
    return nil if skills.nil?

    # 同じ技術は1行だけ（データベースの UNIQUE と同じ決まり）。「その他」の行は技術が空なので対象外
    technology_ids = skills.map(&:technology_id).compact
    errors.add(:skills, :duplicated) if technology_ids.uniq.size != technology_ids.size

    skills
  end

  # 外部リンク。送られるのは { url, title } の行の一覧
  def build_links(rows)
    build_rows(:links, rows, LINKS_MAX) do |row|
      row = row.to_h.with_indifferent_access
      StudentLink.new(student_profile: self, url: row[:url], title: row[:title])
    end
  end

  # 資格。送られるのは資格名の文字の一覧（["基本情報技術者", …]。API設計.md の 16-3 ⑥）
  def build_certifications(names)
    build_rows(:certifications, names, CERTIFICATIONS_MAX) do |name|
      StudentCertification.new(student_profile: self, name: name)
    end
  end

  # 行ごとの付属情報を、送られた内容で消して作り直す（16-3 ⑯）。
  # 募集の職種と同じく、1行ずつ見比べるより、まとめて消して作り直す方が単純で間違えにくい。
  # トランザクションの中で呼ぶので、途中で失敗しても元に戻る
  def replace_rows(model, association, new_rows)
    model.where(student_profile_id: id).delete_all
    association.reset
    new_rows.each(&:save!)
  end
end
