# 学生検索（㉒ GET /api/company/students）の本体。窓口はこれを呼ぶだけにする。
# 詳しくは design/designs/API設計.md の 16-3 ㉒・16-1-11、処理設計_類似度.md の 7-3。
# 募集検索の本体（job_posting_search.rb）と同じ組み立てにしている。
#
# 条件で結果を減らさない。対象の学生（30日以内に活動し、もうスカウトした・見送った・マッチした学生を除く）をすべて返し、
# 指定した条件を「全部」満たす学生を合致の群として先に、1つでも外れる学生を合致外の群としてあとに並べる（技術構成.md の 9-1-1 の1）。
# どちらの群の中も、選んだ並び順（おすすめ順・最終活動が新しい順）で並べる。
# 性格は合致の判定に使わない（サービス概要_コンセプト.md の 2-4）。
# ページ分けはコントローラー（concerns/pagination.rb）が行う。ここでは「並べた一覧」までを作る
class StudentSearch
  # 並び順。recommended は選んだ募集におすすめ順（募集が必要）、last_active は最終活動が新しい順
  SORTS = %w[recommended last_active].freeze

  # フリーワードの対象のうち、学生プロフィールそのものの文章の列（自己PRの3つ）。
  # プログラミング歴の「その他」の名前は、下で別に探す。資格名は、資格の表を作る【仕上げ】で足す。
  # 名前と大学名は対象にしない（16-3 ㉒）
  KEYWORD_COLUMNS = %w[self_pr_strength self_pr_weakness self_pr_future].freeze

  # 稼働条件の数値：学生の上限（週◯日まで）の列。企業が選んだ値以上なら合う（その他決め事.md の 5-6）
  WORK_CONDITION_COLUMNS = %i[work_days_per_week work_hours_per_day duration_months].freeze

  # 勤務形態の名前（募集と同じ）と、学生の「可能」の列
  WORK_STYLE_COLUMNS = {
    "full_remote" => :can_full_remote,
    "partial_remote" => :can_partial_remote,
    "onsite" => :can_onsite
  }.freeze

  # company：検索している会社（募集を選んでいないときの除外に使う）。
  # job_posting：選んだ自社の募集（除外とおすすめの点数に使う）。選んでいなければ nil。
  # params：画面から送られた条件（q、work_days_per_week、work_hours_per_day、duration_months、start_month、work_style、
  #   prefecture_id、technology_ids、min_level、job_major_category_ids、job_middle_category_ids、grades、graduation_years、
  #   activity_statuses、sort）。形のおかしい値や知らない名前は、その条件を「指定なし」として扱う（募集検索と同じゆるさ。PR200）
  def initialize(company:, job_posting:, params:)
    @company = company
    @job_posting = job_posting
    @params = params.to_h.with_indifferent_access
    @sort = decide_sort(@params[:sort])
  end

  # 条件に合う人数（「条件に合う◯人」）。全員の数（「全◯人」）は、ページ分けのときに Pagy が数える
  def matched_count
    matched_scope.count
  end

  # 並べた一覧（ページ分けの前）。
  # 最終活動の順はデータベースの結果（SQL で並べる）、おすすめ順は Ruby の配列（点数を付けて並べる）を返す。
  # どちらも concerns/pagination.rb の paginate でページに分けられる（技術構成.md の 9-1-1 の2）
  def ordered
    @sort == "recommended" ? ordered_by_recommendation : ordered_by_last_active
  end

  # 渡した番号のうち、合致する学生の番号（1ページ分の行に matched を付けるため）
  def matched_ids_in(ids)
    matched_scope.where(id: ids).pluck(:id)
  end

  private

  # おすすめ順は、選んだ募集を元に点数を付けるので、募集がなければ使えない（窓口では 422 にしてある）。
  # 省略や知らない値なら、募集を選んでいればおすすめ順、なければ最終活動の順（16-3 ㉒）
  def decide_sort(sort)
    return "last_active" if @job_posting.nil?

    SORTS.include?(sort) ? sort : "recommended"
  end

  # 対象の学生。システムが決めた除外は、次の2つ（利用者が指定した条件ではなく、全員に同じ基準で当たるため。7-3）
  #   - 30日より前に活動した学生（最終活動日が空の学生も。PR216）
  #   - もうスカウトした・見送った・マッチした学生（excluded_student_ids。PR220）
  # ここで除くので、人数・合致の群と合致外の群・ページ分け・おすすめ順のすべてが、除いた後の学生で計算される
  def base
    @base ||= begin
      scope = StudentProfile.recently_active
      excluded_ids = excluded_student_ids
      excluded_ids ? scope.where.not(id: excluded_ids) : scope
    end
  end

  # 除く学生の番号の一覧（データベースの問い合わせの形。サブクエリとして使う）。除かないなら nil（PR220）
  #   - 募集を選んでいるとき：その募集と「学生検索から外すやりとり」がある学生
  #   - 募集を選んでいないとき：自社の掲載中の募集すべてと、そのやりとりがある学生（どの募集でも、もうスカウトできない学生）。
  #     掲載中の募集が1件もなければ、誰も除かない
  def excluded_student_ids
    return @job_posting.candidacies.excluded_from_student_search.select(:student_profile_id) if @job_posting

    published_postings = @company.job_postings.published
    published_count = published_postings.count
    return nil if published_count.zero?

    # 1つの募集×学生のやりとりは1件だけなので、学生ごとの件数が掲載中の募集の数と同じなら、すべての募集で当てはまる。
    # Django の .values("student_profile").annotate(n=Count("id")).filter(n__gte=掲載中の数) にあたる
    Candidacy.excluded_from_student_search
             .where(job_posting_id: published_postings.select(:id))
             .group(:student_profile_id)
             .having("COUNT(*) >= ?", published_count)
             .select(:student_profile_id)
  end

  # 指定した条件を全部満たす学生。条件が1つもなければ base と同じ（全員が合致）。
  # and は「両方の where を AND でつなぐ」（Django の filter(条件1).filter(条件2) にあたる）
  def matched_scope
    @matched_scope ||= conditions.reduce(base) { |scope, condition| scope.and(condition) }
  end

  # 指定された条件だけを集める。指定がないもの（nil）は入れない
  def conditions
    [
      keyword_condition, *work_condition_conditions, start_month_condition, work_style_condition,
      prefecture_condition, *technology_conditions, job_category_condition,
      grade_condition, graduation_year_condition, activity_status_condition
    ].compact
  end

  # 最終活動の順：合致なら0・合致外なら1 → 最終活動日の新しい順 → 番号の大きい順。
  # 最終活動日はログイン情報（users）の列なので、ここでだけ表を結合する
  def ordered_by_last_active
    matched_sql = matched_scope.select(:id).to_sql
    base.joins(:user).order(
      Arel.sql("CASE WHEN student_profiles.id IN (#{matched_sql}) THEN 0 ELSE 1 END"),
      Arel.sql("users.last_active_on DESC"),
      id: :desc
    )
  end

  # おすすめ順：合致なら0・合致外なら1 → 点数の高い順 → 同点なら最終活動の順（16-3 ㉒）。
  # 点数は StudentRecommender が付ける（今は仮の全員0点なので、並びは最終活動の順と同じ。PR214）
  def ordered_by_recommendation
    students = base.includes(:user).to_a
    scores = StudentRecommender.scores(@job_posting, students)
    matched_ids = matched_scope.pluck(:id).to_set

    students.sort_by do |student|
      [
        matched_ids.include?(student.id) ? 0 : 1,
        -scores.fetch(student.id),
        # 日付を「紀元前からの日数」（jd）にして、新しい日ほど小さくなるよう符号を反転する
        -student.user.last_active_on.jd,
        -student.id
      ]
    end
  end

  # フリーワード：空白（全角の空白も）で区切ったすべての語が、次のどこかに含まれる学生（16-3 ㉒）。
  #   自己PRの3つ、プログラミング歴の「その他」の名前。大文字と小文字は区別しない（ILIKE）
  def keyword_condition
    words = @params[:q].to_s.split(/[[:space:]]+/).compact_blank
    return nil if words.empty?

    words.map { |word| keyword_word_condition(word) }.reduce(:and)
  end

  # 1つの語について、対象のどれかに含まれる学生。
  # プログラミング歴は、表を結合せず「番号がこの一覧に入っているか」（サブクエリ）で探す。
  # 結合すると、プログラミング歴を3行持つ学生が3行に増え、件数が狂うため
  def keyword_word_condition(word)
    # 語の中の % や _ を、「何でも」の意味ではなく、ただの文字として扱う
    pattern = "%#{StudentProfile.sanitize_sql_like(word)}%"

    in_columns = StudentProfile.where(
      KEYWORD_COLUMNS.map { |column| "student_profiles.#{column} ILIKE :pattern" }.join(" OR "),
      pattern: pattern
    )
    other_skill_names = StudentProfile.where(
      id: StudentSkill.where("student_skills.other_name ILIKE ?", pattern).select(:student_profile_id)
    )
    in_columns.or(other_skill_names)
  end

  # 稼働条件の数値（週の日数・1日の時間・継続期間）：学生の上限が、企業が選んだ値以上なら合う
  # （例：「週3日以上」なら「週3日まで」「週5日まで」の学生）。学生が空欄なら合わない（未入力は合致外。その他決め事.md の 5-10）
  def work_condition_conditions
    WORK_CONDITION_COLUMNS.filter_map do |column|
      value = integer_param(column)
      # value.. は「value 以上」（Django の column__gte=value にあたる）。NULL は含まれない
      StudentProfile.where(column => value..) if value
    end
  end

  # 開始時期：学生の開始可能月が、選んだ月以前なら合う。学生が空欄なら合わない。
  # 選んだ月が今月より前なら、条件として使わない（すでに始まっている仕事なので、全員が合う。その他決め事.md の 5-6）
  def start_month_condition
    month = date_param(:start_month)&.beginning_of_month
    return nil unless month
    # 今月は日本時間で数える（API設計.md の 16-1-12）
    return nil if month < Time.zone.today.beginning_of_month

    StudentProfile.where(available_from: ..month)
  end

  # 勤務形態：学生がその勤務形態を「可能」にしていれば合う。1つだけ選ぶ（16-3 ㉒）
  def work_style_condition
    column = WORK_STYLE_COLUMNS[@params[:work_style]]
    return nil unless column

    StudentProfile.where(column => true)
  end

  # 勤務地：学生の出社できる都道府県に含まれれば合う。勤務形態がフルリモートのときは、出社しないので使わない
  def prefecture_condition
    prefecture_id = integer_param(:prefecture_id)
    return nil if prefecture_id.nil? || @params[:work_style] == "full_remote"

    StudentProfile.where(
      id: StudentCommutablePrefecture.where(prefecture_id: prefecture_id).select(:student_profile_id)
    )
  end

  # 使用技術：選んだ技術を「すべて」プログラミング歴に持っていれば合う（募集検索の「どれか1つ」とは違う。16-3 ㉒）。
  #   技術のレベルも選んだら、その技術すべてがそのレベル以上。レベルだけ選んでも使わない。
  #   技術1つにつき条件を1つ作り、conditions の中で全部を AND でつなぐ
  def technology_conditions
    levels = levels_at_or_above(@params[:min_level])

    array_param(:technology_ids).uniq.map do |technology_id|
      skills = StudentSkill.where(technology_id: technology_id)
      skills = skills.where(level: levels) if levels
      StudentProfile.where(id: skills.select(:student_profile_id))
    end
  end

  # 職種：興味のある職種のどれか1つが一致すれば合う。
  #   大分類は「その大分類の中分類すべて」に広げ、送られた中分類と合わせる（募集検索と同じ）
  def job_category_condition
    major_ids = array_param(:job_major_category_ids)
    middle_ids = array_param(:job_middle_category_ids)
    return nil if major_ids.empty? && middle_ids.empty?

    middle_categories = JobMiddleCategory.where(id: middle_ids)
                                         .or(JobMiddleCategory.where(job_major_category_id: major_ids))
    StudentProfile.where(
      id: StudentInterestedJobCategory.where(job_middle_category_id: middle_categories.select(:id)).select(:student_profile_id)
    )
  end

  # 学年：どれかに当てはまれば合う。知らない名前は除く
  def grade_condition
    grades = array_param(:grades) & StudentProfile.grades.keys
    StudentProfile.where(grade: grades) if grades.any?
  end

  # 卒業年度：どれかに当てはまれば合う。整数でない値は除く
  def graduation_year_condition
    years = array_param(:graduation_years).filter_map { |year| Integer(year, exception: false) }
    StudentProfile.where(graduation_year: years) if years.any?
  end

  # 活動状況：どれかに当てはまれば合う。知らない名前は除く。
  # 「今は探していない」の学生も、結果からは外さない（選んだときだけ合う・合わないが決まる。16-3 ㉒）
  def activity_status_condition
    statuses = array_param(:activity_statuses) & StudentProfile.activity_statuses.keys
    StudentProfile.where(activity_status: statuses) if statuses.any?
  end

  # 選んだレベル以上のレベルの名前の一覧（例："v2" なら ["v2", "v3", "v4"]）。知らない名前なら nil（指定なし）
  def levels_at_or_above(name)
    minimum = StudentSkill.levels[name]
    return nil if minimum.nil?

    StudentSkill.levels.select { |_level, number| number >= minimum }.keys
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
