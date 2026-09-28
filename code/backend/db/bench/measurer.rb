# 速さの実測（design/designs/技術構成.md の 9-4-1）で、場面ごとの処理時間を測る処理。
# 入口はコマンド bin/rails bench:measure（lib/tasks/bench.rake。bash dev.sh bench-measure からも呼べる）。
# 測る前に、測定用のデータ（db/bench/loader.rb）を入れておく。
#
# 測る場面（スカウト後・応募完了のポップアップは、作る順で足す）
#   - 募集一覧（学生）のおすすめ順、学生検索のおすすめ順：窓口がする検索の本体の部分（並べる → 件数 → 1ページ目の20件と関連の読み込み →
#     合致の印 → 合致の件数）。JSON を作る部分は含めない。条件なし（群が1つ）と条件あり（群が2つ）の両方
#   - 応募・マッチのときのジョブ（InterestRecordedJob）、全体の作り直し（RecommendationStatsRebuildJob）
#
# 工程ごとの内訳は、推薦の部品が付けた印（*.recommendation。PR307）を受け取って足し合わせる。
#   ① content（内容の近さの SQL）② first_pass（行動の近さと 1次検索の点 F1）③ rerank（上位 R 件の f(P, S)）
#   ④ そのほか（2群への振り分けと並べ替え、20件の取り出しなど）＝ 全体 −（① + ② + ③）
# SQL の本数も、工程ごとに数える（③で N+1 になっていないかを見るため）
class BenchMeasurer
  # 1つの対象（学生・募集・やりとり）を測る回数。その前に1回、準備運動として動かす（読み込みやキャッシュの影響を除く）
  RUNS = 5
  # 測る対象の数（学生5人・募集5件・やりとり5件）
  TARGETS = 5
  RANDOM_SEED = 20_260_928
  # 工程の名前と、画面に出す名前
  STEPS = { "content" => "①内容の近さ", "first_pass" => "②行動の近さと F1", "rerank" => "③並べ直し" }.freeze
  # 数えない SQL（表の形の読み込み、トランザクションの開始・終了）
  IGNORED_SQL_NAMES = %w[SCHEMA TRANSACTION].freeze

  # 測定用のデータがないとき
  class Error < StandardError; end

  # 1回分の結果。total：全体の時間（ミリ秒）、steps：工程ごとの時間、sql：工程ごとの SQL の本数（:all は全体）、
  # rows：工程ごとの件数（① は候補の件数、② は CF を出した組の数）
  Run = Data.define(:total, :steps, :sql, :rows)

  def self.measure(out = $stdout)
    new(out).measure
  end

  def initialize(out)
    @out = out
    @random = Random.new(RANDOM_SEED)
  end

  def measure
    students = StudentProfile.where(user_id: BenchLoader.bench_users.select(:id)).order(:id).to_a
    raise Error, "測定用のデータがありません。先に bash dev.sh bench-load small を実行してください" if students.empty?

    postings = JobPosting.where(company_profile_id: CompanyProfile.where(user_id: BenchLoader.bench_users.select(:id)).select(:id))
                         .order(:id).to_a
    candidacy_count = Candidacy.where(student_profile_id: students.map(&:id)).count
    @out.puts "測定用のデータ：学生#{students.size}人・募集#{postings.size}件・応募#{candidacy_count}件"
    @out.puts "（中央値と最大は、対象 × 回数のすべての回から出す。準備運動の1回は含めない）"
    @out.puts

    without_sql_log do
      measure_searches(sample_students(students), sample_postings(postings))
      measure_jobs(students)
    end
  end

  private

  # ── 対象の選び方 ──

  # 学生：乱数で TARGETS 人
  def sample_students(students)
    students.sample(TARGETS, random: @random)
  end

  # 募集：応募の多い順に2件（重い場合）と、残りから乱数で3件
  def sample_postings(postings)
    counts = JobPostingRecommendationStat.where(job_posting_id: postings.map(&:id)).pluck(:job_posting_id, :interest_count).to_h
    sorted = postings.sort_by { |posting| [ -counts.fetch(posting.id, 0), posting.id ] }
    sorted.first(2) + sorted.drop(2).sample(TARGETS - 2, random: @random)
  end

  # ── 場面 ──

  def measure_searches(students, postings)
    report("募集一覧（学生）のおすすめ順・条件なし（学生#{students.size}人 × #{RUNS}回）", students) do |student|
      search_job_postings(student, {})
    end
    report("募集一覧（学生）のおすすめ順・条件あり：週3日まで（学生#{students.size}人 × #{RUNS}回）", students) do |student|
      search_job_postings(student, { "work_days_per_week" => "3" })
    end
    report("学生検索のおすすめ順・条件なし（募集#{postings.size}件 × #{RUNS}回）", postings) do |posting|
      search_students(posting, {})
    end
    report("学生検索のおすすめ順・条件あり：週3日以上（募集#{postings.size}件 × #{RUNS}回）", postings) do |posting|
      search_students(posting, { "work_days_per_week" => "3" })
    end
  end

  def measure_jobs(students)
    candidacies = Candidacy.interests.where(student_profile_id: students.map(&:id)).order(:id).to_a.sample(TARGETS, random: @random)
    report("応募・マッチのときのジョブ：集計の数え直し（やりとり#{candidacies.size}件 × #{RUNS}回）", candidacies) do |candidacy|
      InterestRecordedJob.perform_now(candidacy)
    end
    # 全体の作り直しは重いので、準備運動なしで1回だけ
    report("全体の作り直し（1回）", [ nil ], runs: 1, warm_up: false) { RecommendationStatsRebuildJob.perform_now }
  end

  # 窓口（Api::Student::JobPostingsController#index）と同じ順で、検索の本体を動かす
  def search_job_postings(student, params)
    search = JobPostingSearch.new(student: student, params: params)
    first_page(search, Api::Student::JobPostingsController::ROW_ASSOCIATIONS)
  end

  # 窓口（Api::Company::StudentsController#index）と同じ順で、検索の本体と、行のタグに使うやりとりの読み込みを動かす
  def search_students(posting, params)
    company = posting.company_profile
    search = StudentSearch.new(company: company, job_posting: posting, params: params.merge("sort" => "recommended"))
    ids = first_page(search, Api::Company::StudentsController::ROW_ASSOCIATIONS)
    posting.candidacies.where(student_profile_id: ids).to_a
    company.candidacies.where(student_profile_id: ids).group(:student_profile_id).count
  end

  # 並べる → 件数（Pagy と同じ count(:all)）→ 1ページ目の行と関連 → 合致の印 → 合致の件数。1ページ目の番号を返す
  def first_page(search, associations)
    ordered = search.ordered
    ordered.count(:all)
    records = ordered.limit(Pagination::PER_PAGE).to_a
    ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
    ids = records.map(&:id)
    search.matched_ids_in(ids)
    search.matched_count
    ids
  end

  # ── 測って出す ──

  def report(title, targets, runs: RUNS, warm_up: true, &block)
    results = targets.flat_map do |target|
      block.call(target) if warm_up
      Array.new(runs) { run_once { block.call(target) } }
    end
    print_report(title, results)
  end

  # 1回動かし、その間に届いた印と SQL を集める。Django でいうと、シグナルの受け取り先を一時的につなぐのに近い
  def run_once
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(/\A(sql\.active_record|\w+\.recommendation)\z/) { |event| events << event }
    started = now
    yield
    build_run(now - started, events)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def build_run(total, events)
    step_events, sql_events = events.partition { |event| event.name.end_with?(".recommendation") }
    sql_events.reject! { |event| IGNORED_SQL_NAMES.include?(event.payload[:name]) || event.payload[:cached] }

    steps = STEPS.keys.to_h { |step| [ step, 0.0 ] }
    sql = STEPS.keys.to_h { |step| [ step, 0 ] }.merge(all: sql_events.size)
    rows = STEPS.keys.to_h { |step| [ step, 0 ] }
    step_events.each do |event|
      step = event.name.delete_suffix(".recommendation")
      steps[step] += event.duration
      rows[step] += event.payload[:rows].to_i
      # 印の時間の中に入る SQL を、その工程の SQL として数える
      sql[step] += sql_events.count { |sql_event| sql_event.time >= event.time && sql_event.end <= event.end }
    end
    Run.new(total: total, steps: steps, sql: sql, rows: rows)
  end

  def print_report(title, results)
    totals = results.map(&:total)
    @out.puts "■ #{title}"
    @out.puts "  全体：中央値 #{ms(median(totals))}／最大 #{ms(totals.max)}"

    # 推薦の部品を通る場面（検索）だけ、工程の内訳を出す
    if results.any? { |result| result.steps.values.sum.positive? }
      step_texts = STEPS.map do |step, label|
        "#{label} #{ms(median(results.map { |result| result.steps[step] }))}#{rows_text(step, median(results.map { |result| result.rows[step] }))}"
      end
      others = median(results.map { |result| result.total - result.steps.values.sum })
      @out.puts "  内訳：#{step_texts.join('　')}　④そのほか #{ms(others)}"
      sql_texts = STEPS.map { |step, label| "#{label[0]} #{median(results.map { |result| result.sql[step] }).round}本" }
      @out.puts "  SQL：全体 #{median(results.map { |result| result.sql[:all] }).round}本（#{sql_texts.join('・')}）"
    else
      @out.puts "  SQL：全体 #{median(results.map { |result| result.sql[:all] }).round}本"
    end
    @out.puts
  end

  def rows_text(step, rows)
    case step
    when "content" then "（候補 #{rows.round}件）"
    when "first_pass" then "（CF の組 #{rows.round}）"
    else ""
    end
  end

  # 開発用の設定では、SQL を1本ずつログに書く（呼び出し元の行も調べる）。その時間が混ざらないよう、測るあいだは止める
  def without_sql_log
    logger = ActiveRecord::Base.logger
    original_level = logger&.level
    logger&.level = Logger::INFO
    yield
  ensure
    logger&.level = original_level if logger
  end

  def median(values)
    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
  end

  def ms(value)
    format("%.1fms", value)
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
  end
end
