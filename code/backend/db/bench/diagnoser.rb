# 速さの診断（design/designs/技術構成.md の 9-4-1）。部品ごとに、相手の数を段階的に増やして時間を測り、
# 「相手が2倍になると時間が何倍になるか」から、比例して増えるのか、2乗のように膨れるのかを見る。
# 中の段階の実測（PR308）で、内容の近さを通る場面がデータ量に比例する以上に重くなったため、原因の部品を突き止めるために作った。
#
# 入口はコマンド bin/rails bench:diagnose（lib/tasks/bench.rake。bash dev.sh bench-diagnose からも呼べる）。
# 測る前に、測定用のデータ（db/bench/loader.rb）を入れておく。
#
# 測る部品
#   内容の近さ（Content）：学生どうし・募集×学生・募集どうし（1人・1件 × 多数）と、並べ直しの U の形（多数 × 200人）
#   行動の近さ（Behavior）：学生どうし・募集どうし
#   近さ f（Similarity。内容と行動を混ぜたもの）：学生どうし・募集どうし（似たもののポップアップ・通知の中身）
#   募集一覧の並べ直し（PostingStudent.for_student）の中身：応募者の読み込み、U の近さ f、I の近さ f、並べ直し全体（PR331）
# SQL の部品は、推薦の部品が作る SQL をそのまま実行する。並べ直し全体は、Ruby での計算も含めて部品をそのまま呼ぶ。
# 相手の数は4段階。1段階ごとに、準備運動の1回のあと RUNS 回測り、中央値を出す。
# 左の学生・募集は、応募がいちばん多いもの（いちばん重い場合）。並べ直しの募集は、応募の多い順に N件（応募者が上限に近い、重い場合）。
#
# 画面には表だけを出す。表と、いちばん多い段階の実行計画（EXPLAIN ANALYZE）は、OUTPUT_PATH のファイルにも書く。
# 表の最後の行に、いちばん多い段階で JIT（重い問い合わせを機械語に変える仕組み）が動いたかと、その時間を出す。
# 応募の数による伸びは、ここでは変えられない（データを入れ直す必要がある）ので、小と中の段階でこの診断を流して比べる
class BenchDiagnoser
  # 1段階を測る回数（準備運動の1回は別）
  RUNS = 3
  # 相手の数の段階（全体を何分の1にするか）
  DIVISORS = [ 8, 4, 2, 1 ].freeze
  # 結果を書くファイル（コンテナの中の code/backend/tmp。手元のパソコンからも読める）
  OUTPUT_PATH = Rails.root.join("tmp/bench_diagnose.txt")

  # 測定用のデータがないとき
  class Error < StandardError; end

  # 1段階の結果。size：相手の数、ms：時間の中央値、rows：返ってきた件数
  Step = Data.define(:size, :ms, :rows)

  # 測る部品。
  #   prepare：相手の数 n を受け取り、測る前の下ごしらえをする（SQL の組み立てや、入力の読み込み。時間に含めない）
  #   run：下ごしらえの結果を受け取って動かし、返ってきた件数を返す（ここだけを測る）
  #   explain：下ごしらえの結果から、実行計画を見る SQL を作る。Ruby の計算を含む部品は nil（実行計画を出さない）
  Part = Data.define(:title, :sizes, :prepare, :run, :explain)

  def self.diagnose(out = $stdout)
    new(out).diagnose
  end

  def initialize(out)
    @out = out
  end

  def diagnose
    @student_ids = bench_students.order(:id).ids
    @posting_ids = bench_postings.order(:id).ids
    raise Error, "測定用のデータがありません。先に bash dev.sh bench-load small を実行してください" if @student_ids.empty?

    @student = StudentProfile.find(heaviest_ids(StudentRecommendationStat, :student_profile_id, @student_ids, 1).first)
    @posting = JobPosting.find(heaviest_ids(JobPostingRecommendationStat, :job_posting_id, @posting_ids, 1).first)
    # 並べ直しの U の右側：その募集に興味を示した学生（L_P 人まで。窓口と同じ取り出し方）
    @applicant_ids = Recommendation::Interests.students_by_posting([ @posting.id ]).fetch(@posting.id, [])
    # 並べ直しの対象の募集（応募の多い順）と、学生が興味を示した募集（I の右側）
    @popular_posting_ids = heaviest_ids(JobPostingRecommendationStat, :job_posting_id, @posting_ids, Recommendation::Parameters::RERANK_SIZE)
    @interested_ids = Recommendation::Interests.postings_by_student([ @student.id ]).fetch(@student.id, [])

    File.open(OUTPUT_PATH, "w") do |file|
      @file = file
      write_header
      without_sql_log { (similarity_parts + rerank_parts).each { |part| diagnose_part(part) } }
    end
    @out.puts "表と、いちばん多い段階の実行計画を #{OUTPUT_PATH.relative_path_from(Rails.root)} に書きました"
  end

  private

  # ── 測る部品 ──

  # 近さの部品（SQL だけ）
  def similarity_parts
    content = Recommendation::Content
    students = sizes(@student_ids.size)
    postings = sizes(@posting_ids.size)
    rerank_lefts = sizes([ Recommendation::Parameters::RERANK_SIZE, @student_ids.size ].min)

    [
      sql_part("内容の近さ：学生どうし（学生1人 × N人）", students) do |n|
        content.student_student_sql([ @student.id ], first_students(n))
      end,
      # 募集×学生は、SQL だけを返す入口がないので、部品を直接作って to_sql を呼ぶ（学生検索の①と同じ SQL になる）
      sql_part("内容の近さ：募集×学生（募集1件 × N人）", students) do |n|
        content.new(:posting_student, content::POSTING, content::STUDENT, [ @posting.id ], first_students(n)).to_sql
      end,
      sql_part("内容の近さ：募集どうし（募集1件 × N件）", postings) do |n|
        content.posting_posting_sql([ @posting.id ], first_postings(n))
      end,
      sql_part("内容の近さ：学生どうし（N人 × その募集の学生#{@applicant_ids.size}人。並べ直しの U の形）", rerank_lefts) do |n|
        content.student_student_sql(first_students(n), @applicant_ids)
      end,
      sql_part("行動の近さ：学生どうし（学生1人 × N人）", students) do |n|
        Recommendation::Behavior.student_student_sql([ @student.id ], first_students(n))
      end,
      sql_part("行動の近さ：募集どうし（募集1件 × N件）", postings) do |n|
        Recommendation::Behavior.posting_posting_sql([ @posting.id ], first_postings(n))
      end,
      sql_part("近さ f：学生どうし（学生1人 × N人。似た学生のポップアップの中身）", students) do |n|
        Recommendation::Similarity.student_student_sql([ @student.id ], first_students(n))
      end,
      sql_part("近さ f：募集どうし（募集1件 × N件。似た募集のポップアップ・通知の中身）", postings) do |n|
        Recommendation::Similarity.posting_posting_sql([ @posting.id ], first_postings(n))
      end
    ]
  end

  # 募集一覧の並べ直し（PostingStudent.for_student）の中身（PR331）。N は並べ直す募集の数（応募の多い順）。
  # 実際の並べ直しと同じく、相手の番号は配列で渡す
  def rerank_parts
    postings = sizes(@popular_posting_ids.size)

    [
      Part.new(
        title: "並べ直し：応募者の読み込み（応募の多い募集 N件 → 興味を示した学生を Ruby に読む。件数は読んだ行の数）",
        sizes: postings,
        prepare: ->(n) { @popular_posting_ids.first(n) },
        run: ->(ids) { Recommendation::Interests.students_by_posting(ids).values.sum(&:size) },
        explain: ->(ids) { Recommendation::Interests.of_postings_sql(JobPosting.where(id: ids).select(:id).to_sql) }
      ),
      sql_part("並べ直し：U の近さ f（学生1人 × 応募の多い募集 N件の応募者全員）", postings) do |n|
        Recommendation::Similarity.student_student_sql([ @student.id ], applicants_of(@popular_posting_ids.first(n)))
      end,
      sql_part("並べ直し：I の近さ f（応募の多い募集 N件 × 学生が興味を示した募集#{@interested_ids.size}件）", postings) do |n|
        Recommendation::Similarity.posting_posting_sql(@popular_posting_ids.first(n), @interested_ids)
      end,
      # 内容の近さは、呼ぶ側が1次検索で出したものを渡すので、ここでは空（どの募集も0点）で渡す
      Part.new(
        title: "並べ直し：全体（PostingStudent.for_student。上の3つと、Ruby での平均の計算）",
        sizes: postings,
        prepare: ->(n) { @popular_posting_ids.first(n) },
        run: ->(ids) { Recommendation::PostingStudent.for_student(@student, ids, {}).size },
        explain: nil
      )
    ]
  end

  # SQL だけの部品。SQL の組み立ては下ごしらえに入れ、実行だけを測る
  def sql_part(title, sizes, &sql_for)
    Part.new(
      title: title, sizes: sizes, prepare: sql_for,
      run: ->(sql) { connection.select_all(sql).length },
      explain: ->(sql) { sql }
    )
  end

  # 全体の 1/8・1/4・1/2・全部（少なくとも1。同じ数は1回だけ）
  def sizes(total)
    DIVISORS.map { |divisor| [ (total / divisor.to_f).ceil, 1 ].max }.uniq
  end

  # 相手の集まり。番号の小さい順に n 人（件）。番号を並べて渡すと、実際の画面（問い合わせを渡す）と計画が変わるので、
  # 問い合わせ（サブクエリ）の形で渡す
  def first_students(n)
    StudentProfile.where(id: bench_students.order(:id).limit(n).select(:id))
  end

  def first_postings(n)
    JobPosting.where(id: bench_postings.order(:id).limit(n).select(:id))
  end

  # 募集たちに興味を示した学生の番号（重複なし。PostingStudent.for_student の U の右側と同じ）
  def applicants_of(posting_ids)
    Recommendation::Interests.students_by_posting(posting_ids).values.flatten.uniq
  end

  def bench_students
    StudentProfile.where(user_id: BenchLoader.bench_users.select(:id))
  end

  def bench_postings
    JobPosting.where(company_profile_id: CompanyProfile.where(user_id: BenchLoader.bench_users.select(:id)).select(:id))
  end

  # 応募（興味）の多い順に limit 件の番号（推薦の集計の件数で比べる）
  def heaviest_ids(stat_model, key, ids, limit)
    stat_model.where(key => ids).order(interest_count: :desc, key => :asc).limit(limit).pluck(key)
  end

  # ── 測って出す ──

  def diagnose_part(part)
    part.run.call(part.prepare.call(part.sizes.first)) # 準備運動
    last_input = nil
    steps = part.sizes.map do |size|
      last_input = part.prepare.call(size)
      rows = nil
      times = Array.new(RUNS) { measure { rows = part.run.call(last_input) } }
      Step.new(size: size, ms: median(times), rows: rows)
    end

    plan = part.explain && explain(part.explain.call(last_input))
    lines = [ "■ #{part.title}", format("  %8s %12s %10s %14s", "相手の数", "時間", "件数", "前の段階から") ]
    steps.each_with_index do |step, index|
      growth = index.zero? ? "―" : growth_text(steps[index - 1], step)
      lines << format("  %8d %10.1fms %10d %14s", step.size, step.ms, step.rows, growth)
    end
    lines << "  → #{judgement(steps)}"
    lines << "  → #{jit_text(plan)}" if plan
    lines << ""
    lines.each { |line| @out.puts line }
    lines.each { |line| @file.puts line }

    write_plan(part.title, plan) if plan
  end

  # 「相手が 2.0倍で時間が 3.9倍」
  def growth_text(previous, current)
    format("数%.1f倍→時間%.1f倍", current.size / previous.size.to_f, current.ms / [ previous.ms, 0.001 ].max)
  end

  # 最初と最後の段階から、時間が相手の数の何乗で増えるか（次数）を出す。1 なら比例、2 なら2乗。
  # 少ない段階では、SQL を送る固定の時間が目立つので、次数は小さめに出る
  def judgement(steps)
    first, last = steps.first, steps.last
    return "段階が1つしかないので、増え方は出せません" if first.size == last.size

    degree = Math.log(last.ms / [ first.ms, 0.001 ].max) / Math.log(last.size / first.size.to_f)
    label = if degree < 1.3 then "ほぼ比例"
    elsif degree < 1.7 then "比例より速く増える"
    else "2乗に近い増え方"
    end
    format("増え方の次数 %.2f（1 なら比例、2 なら2乗）：%s", degree, label)
  end

  # いちばん多い段階の実行計画の行（EXPLAIN ANALYZE。実際に実行して、かかった時間も出す）
  def explain(sql)
    connection.select_values("EXPLAIN (ANALYZE, BUFFERS) #{sql}")
  end

  # 実行計画の「JIT: … Timing: … Total 2399.9 ms」から、JIT が動いたかと、その時間を出す
  def jit_text(plan)
    total = plan.filter_map { |line| line[/Timing:.*Total ([\d.]+) ms/, 1] }.first
    total ? "JIT：動いた（#{total}ms。いちばん多い段階の実行計画から）" : "JIT：動いていない"
  end

  # 実行計画を、ファイルにだけ書く
  def write_plan(title, plan)
    @file.puts "── 実行計画：#{title}（いちばん多い段階）"
    plan.each { |line| @file.puts line }
    @file.puts
    @file.puts
  end

  def write_header
    @file.puts "速さの診断（#{Time.current.strftime('%Y-%m-%d %H:%M')}）"
    @file.puts "測定用のデータ：学生#{@student_ids.size}人・募集#{@posting_ids.size}件・" \
               "応募#{Candidacy.where(student_profile_id: @student_ids).count}件"
    @file.puts "左の学生：#{@student.id}（応募#{@student.recommendation_stat&.interest_count}件）、" \
               "左の募集：#{@posting.id}（応募#{@posting.recommendation_stat&.interest_count}件）"
    @file.puts "並べ直しの募集：応募の多い順に#{@popular_posting_ids.size}件（応募者は計算に使う上限 L_P 人まで）"
    @file.puts "時間は、準備運動の1回のあと#{RUNS}回測った中央値"
    @file.puts
  end

  def connection
    ActiveRecord::Base.connection
  end

  def measure
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond) - started
  end

  def median(values)
    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
  end

  # 開発用の設定では、SQL を1本ずつログに書く。その時間が混ざらないよう、測るあいだは止める（measurer.rb と同じ）
  def without_sql_log
    logger = ActiveRecord::Base.logger
    original_level = logger&.level
    logger&.level = Logger::INFO
    yield
  ensure
    logger&.level = original_level if logger
  end
end
