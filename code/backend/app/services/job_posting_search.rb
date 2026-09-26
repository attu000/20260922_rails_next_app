# 募集検索（⑱ GET /api/student/job_postings）の本体。窓口はこれを呼ぶだけにする。
# 詳しくは design/designs/API設計.md の 16-3 ⑱・16-1-11、処理設計_類似度.md の 7-3。
#
# 条件で結果を減らさない。掲載中の募集をすべて返し、指定した条件を「全部」満たすものを合致の群として先に、
# 1つでも外れるものを合致外の群としてあとに並べる（技術構成.md の 9-1-1 の1）。
# どちらの群の中も、選んだ並び順（おすすめ順・新着順）で並べる。
# ページ分けはコントローラー（concerns/pagination.rb）が行う。ここでは「並べた一覧」までを作る
class JobPostingSearch
  # 並び順。省略や知らない値は、既定のおすすめ順にする
  SORTS = %w[recommended newest].freeze
  DEFAULT_SORT = "recommended"

  # フリーワードの対象のうち、募集そのものの文章の列（PR198）。
  # どんな会社か・事業内容は、募集が空欄なら企業プロフィールの文章が画面に出るので、下で別に探す。
  # 会社名・使用技術の名前・職種の名前も、下で別に探す
  KEYWORD_COLUMNS = %w[
    title internship_details growth
    work_style_note work_location_note work_note
    requirements preferred_requirements technology_note
  ].freeze

  # 募集が空欄なら企業プロフィールの値を画面に出す列（API設計.md の 16-3 ⑲）
  KEYWORD_FALLBACK_COLUMNS = %w[about business_description].freeze

  # ③ 稼働条件の数値：学生が選んだ上限（例：週3日まで）と、比べる募集の下限（週◯日以上）の列（その他決め事.md の 5-6）
  WORK_CONDITION_COLUMNS = {
    work_days_per_week: :min_work_days_per_week,
    work_hours_per_day: :min_work_hours_per_day,
    duration_months: :min_duration_months
  }.freeze

  # student：検索している学生（おすすめの点数に使う）。
  # params：画面から送られた条件（q、prefecture_ids、job_major_category_ids、job_middle_category_ids、technology_ids、
  #   work_days_per_week、work_hours_per_day、duration_months、available_from、work_styles、weekend_ok、sort）。
  #   数でない・日付でない・知らない名前などの値は、その条件を「指定なし」として扱う（並び順・ページ番号と同じゆるさ。PR200）
  def initialize(student:, params:)
    @student = student
    @params = params.to_h.with_indifferent_access
    @sort = SORTS.include?(@params[:sort]) ? @params[:sort] : DEFAULT_SORT
  end

  # 条件に合う件数。全件の数（「全◯件」）は、ページ分けのときに Pagy が数える（「条件に合う◯件」）
  def matched_count
    matched_scope.count
  end

  # 並べた一覧（ページ分けの前）。
  # 新着順はデータベースの結果（SQL で並べる）、おすすめ順は Ruby の配列（点数を付けて並べる）を返す。
  # どちらも concerns/pagination.rb の paginate でページに分けられる（技術構成.md の 9-1-1 の2）
  def ordered
    @sort == "newest" ? ordered_by_newest : ordered_by_recommendation
  end

  # 渡した番号のうち、合致する募集の番号（1ページ分の行に matched を付けるため）
  def matched_ids_in(ids)
    matched_scope.where(id: ids).pluck(:id)
  end

  private

  # 対象は掲載中の募集すべて。システムが決めた除外はこれだけ（利用者が指定した条件ではないため。7-3）
  def base
    JobPosting.published
  end

  # 指定した条件を全部満たす募集。条件が1つもなければ base と同じ（全件が合致）。
  # and は「両方の where を AND でつなぐ」（Django の filter(条件1).filter(条件2) にあたる）
  def matched_scope
    @matched_scope ||= conditions.reduce(base) { |scope, condition| scope.and(condition) }
  end

  # 指定された条件だけを集める。指定がないもの（nil）は入れない
  def conditions
    [
      keyword_condition, prefecture_condition, job_category_condition, technology_condition,
      *work_condition_conditions, start_month_condition, work_style_condition, weekend_condition
    ].compact
  end

  # 新着順：合致なら0・合致外なら1 → 最初に掲載した日時の新しい順 → 番号の大きい順。
  # Django の annotate(group=Case(When(id__in=合致, then=0), default=1)).order_by("group", "-published_at", "-id") にあたる。
  # to_sql は、値を Rails が安全な形（引用符で囲むなど）に直した SQL を返す
  def ordered_by_newest
    matched_sql = matched_scope.select(:id).to_sql
    base.order(
      Arel.sql("CASE WHEN job_postings.id IN (#{matched_sql}) THEN 0 ELSE 1 END"),
      published_at: :desc,
      id: :desc
    )
  end

  # おすすめ順：合致なら0・合致外なら1 → 点数の高い順 → 同点なら新着順（16-3 ⑱）。
  # 点数は JobPostingRecommender が付ける（今は仮の全件0点なので、並びは新着順と同じ）
  def ordered_by_recommendation
    job_postings = base.to_a
    scores = JobPostingRecommender.scores(@student, job_postings)
    matched_ids = matched_scope.pluck(:id).to_set

    job_postings.sort_by do |job_posting|
      [
        matched_ids.include?(job_posting.id) ? 0 : 1,
        -scores.fetch(job_posting.id),
        -job_posting.published_at.to_f,
        -job_posting.id
      ]
    end
  end

  # ① フリーワード：空白（全角の空白も）で区切ったすべての語が、次のどこかに含まれる募集（PR198）。
  #   募集詳細の画面に出る文章すべて（タイトル、募集概要の4つ、必須要件、歓迎要件、使用技術の補足、
  #   勤務形態の補足、最寄り駅など、稼働の備考）と、会社名、使用技術の名前、職種（中分類と大分類）の名前。
  #   都道府県と勤務形態の名前は対象にしない（専用の条件欄で探す）。大文字と小文字は区別しない（ILIKE）
  def keyword_condition
    words = @params[:q].to_s.split(/[[:space:]]+/).compact_blank
    return nil if words.empty?

    words.map { |word| keyword_word_condition(word) }.reduce(:and)
  end

  # 1つの語について、対象のどれかに含まれる募集。
  # 会社・技術・職種は、テーブルを結合せず「番号がこの一覧に入っているか」（サブクエリ）で探す。
  # 結合すると、技術を3つ使う募集が3行に増え、件数が狂うため
  def keyword_word_condition(word)
    # 語の中の % や _ を、「何でも」の意味ではなく、ただの文字として扱う
    pattern = "%#{JobPosting.sanitize_sql_like(word)}%"

    in_columns = JobPosting.where(
      KEYWORD_COLUMNS.map { |column| "job_postings.#{column} ILIKE :pattern" }.join(" OR "),
      pattern: pattern
    )
    company_names = JobPosting.where(
      company_profile_id: CompanyProfile.where("company_profiles.name ILIKE ?", pattern).select(:id)
    )
    technology_names = JobPosting.where(
      id: JobPostingTechnology
        .where(technology_id: Technology.where("technologies.name ILIKE ?", pattern).select(:id))
        .select(:job_posting_id)
    )

    # どれか1つに含まれれば合う（OR でつなぐ）
    [
      in_columns,
      *KEYWORD_FALLBACK_COLUMNS.map { |column| fallback_text_condition(column, pattern) },
      company_names,
      technology_names,
      job_category_name_condition(pattern)
    ].reduce(:or)
  end

  # どんな会社か・事業内容は、画面に出ている方の文章で探す。
  # 募集に書いてあれば募集の文章で、募集が空欄なら企業プロフィールの文章で探す。
  # 募集に書いてあるとき、画面に出ない企業プロフィールの文章では探さない（なぜ出たのか分からなくなるため）。
  # Django の Q(about__icontains=w) | Q(about__isnull=True, company_profile__about__icontains=w) にあたる
  def fallback_text_condition(column, pattern)
    in_posting = JobPosting.where("job_postings.#{column} ILIKE ?", pattern)
    in_company = JobPosting.where(column => nil).where(
      company_profile_id: CompanyProfile.where("company_profiles.#{column} ILIKE ?", pattern).select(:id)
    )
    in_posting.or(in_company)
  end

  # 職種の名前：名前が含まれる中分類か、名前が含まれる大分類の中の中分類を、主・関連のどちらかに持つ募集。
  # 説明文は対象にしない（「データ」のような語で、関係の薄い募集まで合ってしまうため）
  def job_category_name_condition(pattern)
    middle_categories = JobMiddleCategory.where("job_middle_categories.name ILIKE ?", pattern).or(
      JobMiddleCategory.where(
        job_major_category_id: JobMajorCategory.where("job_major_categories.name ILIKE ?", pattern).select(:id)
      )
    )
    JobPosting.where(
      id: JobPostingJobCategory.where(job_middle_category_id: middle_categories.select(:id)).select(:job_posting_id)
    )
  end

  # ② 勤務地：勤務地がどれかに当てはまる募集。フルリモートの募集は、勤務地に関係なく合う。
  #   勤務地が空欄で、フルリモートでもない募集は合わない（未入力は合致外。その他決め事.md の 5-10）
  def prefecture_condition
    prefecture_ids = array_param(:prefecture_ids)
    return nil if prefecture_ids.empty?

    JobPosting.where(work_style: :full_remote).or(JobPosting.where(prefecture_id: prefecture_ids))
  end

  # ④ 職種：主・関連のどれか1つが一致する募集。
  #   大分類は「その大分類の中分類すべて」に広げ、送られた中分類と合わせる
  def job_category_condition
    major_ids = array_param(:job_major_category_ids)
    middle_ids = array_param(:job_middle_category_ids)
    return nil if major_ids.empty? && middle_ids.empty?

    middle_categories = JobMiddleCategory.where(id: middle_ids)
                                         .or(JobMiddleCategory.where(job_major_category_id: major_ids))
    JobPosting.where(
      id: JobPostingJobCategory.where(job_middle_category_id: middle_categories.select(:id)).select(:job_posting_id)
    )
  end

  # ④ 使用技術（PR199）：選んだ技術のどれか1つを使用技術に持つ募集。
  #   フリーワードでは拾えない表記の揺れ（「JS」と「JavaScript」など）を、マスタから選んで探せるようにする
  def technology_condition
    technology_ids = array_param(:technology_ids)
    return nil if technology_ids.empty?

    JobPosting.where(
      id: JobPostingTechnology.where(technology_id: technology_ids).select(:job_posting_id)
    )
  end

  # ③ 稼働条件の数値（週の日数・1日の時間・継続期間。PR200）：
  #   募集の下限が、学生が選んだ上限以下なら合う（例：「週3日まで」なら「週2日以上」「週3日以上」の募集）。
  #   募集が空欄なら合わない（未入力は合致外。その他決め事.md の 5-10）
  def work_condition_conditions
    WORK_CONDITION_COLUMNS.filter_map do |param_key, column|
      value = integer_param(param_key)
      # ..value は「value 以下」（Django の column__lte=value にあたる）。NULL は含まれない
      JobPosting.where(column => ..value) if value
    end
  end

  # ③ 開始時期（PR200）：学生が「この月から働ける」を選ぶ。次のどれかなら合う（その他決め事.md の 5-6）
  #   - 募集が随時（空欄）
  #   - 募集の開始月が今月より前（すでに始まっている仕事なので、いつ入ってもよい）
  #   - 募集の開始月が、学生が働ける月以降
  def start_month_condition
    from = date_param(:available_from)&.beginning_of_month
    return nil unless from

    # 今月は日本時間で数える（API設計.md の 16-1-12）
    this_month = Time.zone.today.beginning_of_month
    JobPosting.where(start_month: nil)
              .or(JobPosting.where(start_month: ...this_month))
              .or(JobPosting.where(start_month: from..))
  end

  # ③ 勤務形態（PR200）：募集の勤務形態が、学生が選んだものに含まれれば合う。募集が空欄なら合わない
  def work_style_condition
    work_styles = array_param(:work_styles) & JobPosting.work_styles.keys
    return nil if work_styles.empty?

    JobPosting.where(work_style: work_styles)
  end

  # ③ 土日OK（PR200）：true なら、土日OK の募集だけが合う。false や指定なしなら条件にしない
  def weekend_condition
    return nil unless ActiveModel::Type::Boolean.new.cast(@params[:weekend_ok])

    JobPosting.where(weekend_ok: true)
  end

  # 配列の条件を取り出す。空の値は除く（空の配列は「指定なし」）
  def array_param(key)
    Array(@params[key]).compact_blank
  end

  # 整数の条件を取り出す。整数でなければ nil（指定なし）
  def integer_param(key)
    Integer(@params[key], exception: false)
  end

  # 日付の条件を取り出す（"2026-11-01"）。日付でなければ nil（指定なし）
  def date_param(key)
    Date.iso8601(@params[key].to_s)
  rescue Date::Error
    nil
  end
end
