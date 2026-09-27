# 学生1人と募集1件の比較（design/designs/ページ設計.md の 6-5 C6、API設計.md の 16-3 ㉓）。
# 学生詳細で、業界・職種・使用技術・稼働条件のどこが一致しているかを返す。
# 判定は Rails のここ1か所で行い、画面は結果を見てオレンジの枠を付けるだけにする（API設計.md の 16-1-9）。
# 未入力の扱いは、その他決め事.md の 5-10（どちらかが未入力なら判定しない）。
#
# カルチャーは計算しない。画面は学生と募集の値を1本の線に置いて、2点の間に線を引くだけで、
# 「近い・遠い」の判定はしないため（背景の強調をやめた。PR259）。
#
# 関連は、読み込み済みのものを map で使う（pluck でその場で問い合わせない）。
# 学生詳細は自社の全募集ぶんを一度に比べるので、窓口が関連を最初にまとめて読み込めるようにするため（N+1問題を避ける）
class StudentJobPostingComparison
  # 稼働条件の項目。並びは画面に出す順（その他決め事.md の 5-6）
  WORK_CONDITION_ITEMS = %w[
    work_days_per_week work_hours_per_day duration_months start_month work_style work_location
  ].freeze

  # 数の項目の、学生の列（上限）と募集の列（下限）の組
  NUMERIC_COLUMNS = {
    "work_days_per_week" => %i[work_days_per_week min_work_days_per_week],
    "work_hours_per_day" => %i[work_hours_per_day min_work_hours_per_day],
    "duration_months" => %i[duration_months min_duration_months]
  }.freeze

  # 募集の勤務形態と、学生の「可能」の列の組
  WORK_STYLE_COLUMNS = {
    "full_remote" => :can_full_remote,
    "partial_remote" => :can_partial_remote,
    "onsite" => :can_onsite
  }.freeze

  def initialize(student:, job_posting:)
    @student = student
    @job_posting = job_posting
  end

  # 返すもの：
  #   industry_ids・job_middle_category_ids・technology_ids：{ matched: 両方にある番号 }。どちらかが空なら nil（画面は「未入力」）
  #   work_conditions：項目ごとに { item:, result: } の配列。result は match（一致）／mismatch（不一致）／not_judged（未入力）
  def result
    {
      industry_ids: matched_ids(
        @student.student_interested_industries.map(&:industry_id),
        @job_posting.job_posting_industries.map(&:industry_id)
      ),
      # 募集側は、メインとサブの職種を合わせた一覧
      job_middle_category_ids: matched_ids(
        @student.student_interested_job_categories.map(&:job_middle_category_id),
        @job_posting.job_posting_job_categories.map(&:job_middle_category_id)
      ),
      # 学生側は、プログラミング歴のうちマスタから選んだ技術だけ。「その他」の行は番号がないので比べない
      technology_ids: matched_ids(
        @student.student_skills.filter_map(&:technology_id),
        @job_posting.job_posting_technologies.map(&:technology_id)
      ),
      work_conditions: WORK_CONDITION_ITEMS.map { |item| { item: item, result: work_condition_result(item) } }
    }
  end

  private

  # 番号の重なり。どちらかが空なら nil、それ以外は両方にある番号（重なりがなければ空の配列）
  def matched_ids(student_ids, job_posting_ids)
    return nil if student_ids.empty? || job_posting_ids.empty?

    { matched: student_ids & job_posting_ids }
  end

  def work_condition_result(item)
    case item
    when *NUMERIC_COLUMNS.keys then numeric_result(*NUMERIC_COLUMNS.fetch(item))
    when "start_month" then start_month_result
    when "work_style" then work_style_result
    when "work_location" then work_location_result
    end
  end

  # 週の日数・1日の時間・継続期間：学生の上限が募集の下限以上なら一致
  def numeric_result(student_column, job_posting_column)
    student_value = @student.public_send(student_column)
    job_posting_value = @job_posting.public_send(job_posting_column)
    return "not_judged" if student_value.nil? || job_posting_value.nil?

    student_value >= job_posting_value ? "match" : "mismatch"
  end

  # 開始時期：募集が随時（空欄）か、開始月が今月より前（すでに始まっている仕事）なら、学生が空でも一致。
  # それ以外は、学生がその月までに働き始められれば一致
  def start_month_result
    job_posting_month = @job_posting.start_month
    # 今月は日本時間で数える（API設計.md の 16-1-12）
    return "match" if job_posting_month.nil? || job_posting_month < Time.zone.today.beginning_of_month
    return "not_judged" if @student.available_from.nil?

    @student.available_from <= job_posting_month ? "match" : "mismatch"
  end

  # 勤務形態：募集の勤務形態を、学生が「可能」にしていれば一致。
  # 学生の勤務形態は、未入力と「すべて可能」を区別しないので、学生側の未入力はない（その他決め事.md の 5-10）
  def work_style_result
    return "not_judged" if @job_posting.work_style.nil?

    @student.public_send(WORK_STYLE_COLUMNS.fetch(@job_posting.work_style)) ? "match" : "mismatch"
  end

  # 勤務地：フルリモートなら問わない（一致）。それ以外は、募集の都道府県が学生の出社できる都道府県に入っていれば一致。
  # 学生の出社できる都道府県が空なら、通えないのではなく答えていないだけなので「未入力」（PR257。検索では合致外のまま。PR261）
  def work_location_result
    return "match" if @job_posting.full_remote?
    return "not_judged" if @job_posting.prefecture_id.nil?

    commutable_ids = @student.student_commutable_prefectures.map(&:prefecture_id)
    return "not_judged" if commutable_ids.empty?

    commutable_ids.include?(@job_posting.prefecture_id) ? "match" : "mismatch"
  end
end
