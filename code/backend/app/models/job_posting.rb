# 募集（design/designs/データベース.md の 8-5）。
# 必須は2段（その他決め事.md の 5-9、権限_バリデーション.md の 17-3-3）。
#   常に必須：状態、タイトル、カルチャー5軸（初期値が中央なので、実質そろっている）
#   掲載に必要（状態が掲載中のときだけ必須）：インターンですること、時給
# 非公開なら書きかけでも保存できる（下書きとして使う）。必須要件は、名前に「必須」と付くが入力は任意
class JobPosting < ApplicationRecord
  include WorkConditions
  include MasterIdsValidation
  # カルチャーの5軸。学生の働き方の好みと共通（concerns/culture_axes.rb）
  include CultureAxes

  # 時給の上限（桁の打ち間違いを弾くため。権限_バリデーション.md の 17-3-4）
  HOURLY_WAGE_MAX = 100_000

  belongs_to :company_profile
  # 勤務地（任意）
  belongs_to :prefecture, optional: true

  # 職種。主と関連を1つのテーブルで持ち、role で分ける（主・関連を分けた番号の一覧は、下のメソッドで取り出す）
  has_many :job_posting_job_categories
  # 使用技術。Django の ManyToManyField(through=...) にあたる
  has_many :job_posting_technologies
  has_many :technologies, through: :job_posting_technologies
  # 工程。職種と同じく、メインと関われるを1つのテーブルで持ち、role で分ける
  has_many :job_posting_work_processes
  # 業界・事業形態（どちらも任意、複数）。through を書くと、industry_ids・business_type_ids が自動でできる。
  # 企業プロフィールの値とは別に持ち、空欄でも企業の値で補わない。検索・おすすめ・比較にはこちらを使う（その他決め事.md の 5-8）
  has_many :job_posting_industries
  has_many :industries, through: :job_posting_industries
  has_many :job_posting_business_types
  has_many :business_types, through: :job_posting_business_types
  # この募集とのやりとり（応募・スカウト）
  has_many :candidacies

  # 状態と勤務形態。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。範囲外の値は検証エラーにする
  enum :status, {
    unpublished: 0,
    published: 1,
    closed: 2
  }, validate: { allow_nil: true }
  enum :work_style, {
    full_remote: 0,
    partial_remote: 1,
    onsite: 2
  }, validate: { allow_nil: true }

  # 任意の文章が空白だけで送られてきたら、空欄（null）にそろえて保存する。
  # - どんな会社か・事業内容が空欄なら null を返す、という窓口の決まりを守るため（API設計.md の 16-3 ⑫）
  # - 空白だけのインターンですることで掲載中にされるのを防ぐため（データベースの CHECK は null しか見ない）
  normalizes :about, :business_description, :internship_details, :growth,
             :work_style_note, :work_location_note, :work_note,
             :requirements, :preferred_requirements, :technology_note,
             with: ->(value) { value.presence }

  # 常に必須
  validates :status, presence: true
  validates :title, presence: true, length: { maximum: 100 }
  # 掲載に必要：状態が掲載中のときだけ確かめる（データベースの CHECK でも同じ決まりを守る）
  validates :internship_details, :hourly_wage, presence: true, if: :published?
  # 時給は、入っていれば 1〜100,000 の整数
  validates :hourly_wage, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: HOURLY_WAGE_MAX
  }, allow_nil: true
  # 形式と長さの決まり（権限_バリデーション.md の 17-3-4）
  validates :work_style_note, :work_location_note, length: { maximum: 100 }
  validates :about, :business_description, :internship_details, :growth, :work_note,
            :requirements, :preferred_requirements, :technology_note,
            length: { maximum: 2000 }
  # 稼働条件の3つの数値（選択肢は concerns/work_conditions.rb）
  validates_work_conditions days: :min_work_days_per_week,
                            hours: :min_work_hours_per_day,
                            months: :min_duration_months
  # カルチャーの5軸は、−2〜2 の整数（concerns/culture_axes.rb）
  validates_culture_axes :culture
  validate :start_month_must_be_first_day
  # 勤務地の番号が都道府県にあるか（concerns/master_ids_validation.rb）
  validate { validate_master_id(:prefecture_id, prefecture_id, Prefecture) }
  validate :cannot_create_as_closed, on: :create

  # 初めて掲載中にしたときだけ、最初に掲載した日時を記録する。再掲載しても変えない（権限_バリデーション.md の 17-2-2）。
  # Django で save() を上書きして、保存の直前に値を入れるのにあたる
  before_save :record_first_published_at

  # 主な中分類の番号の一覧（画面に返すとき用。フォームの入力欄とそのまま対応させる。API設計.md の 16-3 ⑫）
  def main_job_middle_category_ids
    job_posting_job_categories.select(&:main?).map(&:job_middle_category_id)
  end

  # 関連する中分類の番号の一覧
  def related_job_middle_category_ids
    job_posting_job_categories.select(&:related?).map(&:job_middle_category_id)
  end

  # メインで担当する工程の番号の一覧（職種と同じく、フォームの入力欄とそのまま対応させる。API設計.md の 16-3 ⑫）
  def main_work_process_ids
    job_posting_work_processes.select(&:main?).map(&:work_process_id)
  end

  # 関われる工程の番号の一覧
  def involved_work_process_ids
    job_posting_work_processes.select(&:involved?).map(&:work_process_id)
  end

  # 募集の保存（⑬ 新規作成・⑭ 保存）。窓口はこれを呼ぶだけにする（技術構成.md の 9-1-1 の4、9-2）。
  # 保存できたら true、入力に誤りがあれば false を返す（誤りは errors に入る）。
  # 企業プロフィールの update_profile と同じく、「先に全部確かめてから、トランザクションの中で書き込む」順番にしている
  def save_posting(attributes)
    attributes = attributes.to_h.symbolize_keys
    main_ids = attributes.delete(:main_job_middle_category_ids)
    related_ids = attributes.delete(:related_job_middle_category_ids)
    main_process_ids = attributes.delete(:main_work_process_ids)
    involved_process_ids = attributes.delete(:involved_work_process_ids)
    technology_ids = attributes.delete(:technology_ids)
    industry_ids = attributes.delete(:industry_ids)
    business_type_ids = attributes.delete(:business_type_ids)

    # ① 本体の値を、保存せずにモデルに入れるだけ
    assign_attributes(attributes)

    # ② 検証する。③ 番号の一覧を確かめる
    valid?
    validate_master_ids(:main_job_middle_category_ids, main_ids, JobMiddleCategory)
    validate_master_ids(:related_job_middle_category_ids, related_ids, JobMiddleCategory)
    validate_master_ids(:main_work_process_ids, main_process_ids, WorkProcess)
    validate_master_ids(:involved_work_process_ids, involved_process_ids, WorkProcess)
    validate_master_ids(:technology_ids, technology_ids, Technology)
    validate_master_ids(:industry_ids, industry_ids, Industry)
    validate_master_ids(:business_type_ids, business_type_ids, BusinessType)

    # 職種は、主か関連のどちらかが送られてきたら置き換える。送られなかった側は今の内容のままにする
    # （画面は常に両方送る。画面を通さずに API を呼ばれたときへの備え）
    unless main_ids.nil? && related_ids.nil?
      main_ids = main_ids.nil? ? main_job_middle_category_ids : Array(main_ids)
      related_ids = related_ids.nil? ? related_job_middle_category_ids : Array(related_ids)
      validate_job_categories_not_overlapping(main_ids, related_ids)
    end

    # 工程も職種と同じ。メインか関われるのどちらかが送られてきたら置き換え、送られなかった側は今の内容のままにする
    unless main_process_ids.nil? && involved_process_ids.nil?
      main_process_ids = main_process_ids.nil? ? main_work_process_ids : Array(main_process_ids)
      involved_process_ids = involved_process_ids.nil? ? involved_work_process_ids : Array(involved_process_ids)
      validate_work_processes_not_overlapping(main_process_ids, involved_process_ids)
    end

    # ④ 誤りが1つでもあれば、何も書き込まずに終わる
    return false if errors.any?

    # ⑤ まとめて書き込む。途中で失敗したら、すべて取り消す（Django の transaction.atomic() にあたる）
    transaction do
      save!
      replace_job_categories(main_ids, related_ids) unless main_ids.nil?
      replace_work_processes(main_process_ids, involved_process_ids) unless main_process_ids.nil?
      # 使用技術・業界・事業形態を、送られた一覧でまるごと置き換える（16-3 ⑭）。送られなかったら変えない
      self.technology_ids = technology_ids unless technology_ids.nil?
      self.industry_ids = industry_ids unless industry_ids.nil?
      self.business_type_ids = business_type_ids unless business_type_ids.nil?
      # 最終更新日は「企業が最後に保存した日」にする。
      # Rails は本体の列が変わったときだけ updated_at を変えるので、職種や技術だけを直したときなど、
      # 本体が変わらなかった場合は touch（updated_at だけを今にする）で更新する
      touch unless saved_changes?
    end
    # 【強み】の順12 で、ここに「トランザクションが確定したら推薦のジョブを呼ぶ」処理を足す（技術構成.md の 9-1-1 の4）
    true
  end

  private

  def record_first_published_at
    self.published_at ||= Time.current if published?
  end

  # 開始時期は月の1日の日付。範囲の制限はない（過去の月も選べる。その他決め事.md の 5-6）
  def start_month_must_be_first_day
    errors.add(:start_month, :invalid) if start_month.present? && start_month.day != 1
  end

  # 新規作成のときは、非公開か掲載中だけを選べる（権限_バリデーション.md の 17-2-2）
  def cannot_create_as_closed
    errors.add(:status, :inclusion) if closed?
  end

  # 同じ中分類を、主と関連の両方には入れられない（その他決め事.md の 5-7、権限_バリデーション.md の 17-3-6）
  def validate_job_categories_not_overlapping(main_ids, related_ids)
    overlapping = main_ids.map(&:to_s) & related_ids.map(&:to_s)
    errors.add(:related_job_middle_category_ids, :overlaps_main_job_categories) if overlapping.any?
  end

  # 職種を、送られた内容でまるごと作り直す。
  # 同じ中分類が主から関連に移ることがあるので、1行ずつ見比べるより、まとめて消して作り直す方が単純で間違えにくい。
  # トランザクションの中で呼ぶので、途中で失敗しても元に戻る
  def replace_job_categories(main_ids, related_ids)
    JobPostingJobCategory.where(job_posting_id: id).delete_all
    job_posting_job_categories.reset
    main_ids.each { |category_id| job_posting_job_categories.create!(job_middle_category_id: category_id, role: :main) }
    related_ids.each { |category_id| job_posting_job_categories.create!(job_middle_category_id: category_id, role: :related) }
  end

  # 同じ工程を、メインと関われるの両方には入れられない（職種と同じ決まり。PR242）
  def validate_work_processes_not_overlapping(main_ids, involved_ids)
    overlapping = main_ids.map(&:to_s) & involved_ids.map(&:to_s)
    errors.add(:involved_work_process_ids, :overlaps_main_work_processes) if overlapping.any?
  end

  # 工程を、送られた内容でまるごと作り直す。職種と同じく、同じ工程がメインから関われるに移ることがあるため
  def replace_work_processes(main_ids, involved_ids)
    JobPostingWorkProcess.where(job_posting_id: id).delete_all
    job_posting_work_processes.reset
    main_ids.each { |process_id| job_posting_work_processes.create!(work_process_id: process_id, role: :main) }
    involved_ids.each { |process_id| job_posting_work_processes.create!(work_process_id: process_id, role: :involved) }
  end
end
