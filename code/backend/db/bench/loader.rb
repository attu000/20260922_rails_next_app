# 速さの実測（design/designs/技術構成.md の 9-4-1）に使う、測定用のデータを作る処理。
# 入口はコマンド bin/rails bench:load[small]（lib/tasks/bench.rake。bash dev.sh bench-load からも呼べる）。
#
# - 仮のデータ（db/demo/loader.rb）とは別物。メールアドレスが bench- で始まるアカウントと、それにつながるものだけを作り、消す
# - 何度実行しても同じ状態になるよう、前回の測定用のデータを消してから作り直す。乱数の種も固定する（仮のデータと同じ）
# - 企業・学生・募集は、画面の操作と同じモデルの処理（新規登録・募集の保存）を通す（仮のデータの PR266 と同じ）
# - 応募と応募理由は、insert_all でまとめて入れる（PR306）。中の段階では5万件になり、1件ずつ応募すると
#   応募のジョブが5万個積まれるため。最後に全体の作り直しを1回して、推薦の集計をそろえる
# - 全体を1つのトランザクションで行う。途中で1つでも確かめに通らなければ、すべて取り消す
class BenchLoader
  # データ量の段階（技術構成.md の 9-4-1）。大（学生10万人）は、中までの実測から計算で外挿するので作らない
  SIZES = {
    small: { students: 100, job_postings: 100, applications_per_student: 3 },
    medium: { students: 5_000, job_postings: 1_000, applications_per_student: 10 }
  }.freeze
  # 企業は、募集この件数ごとに1社
  POSTINGS_PER_COMPANY = 10

  EMAIL_PREFIX = "bench-"
  EMAIL_DOMAIN = "@example.com"
  PASSWORD = "password"
  RANDOM_SEED = 20_260_928

  # 項目を空欄にする割合（実際にも未入力の人がいるため）
  BLANK_RATE = 0.2
  # 応募と応募理由を insert_all でまとめて入れるときの、1回あたりの行数
  INSERT_BATCH_SIZE = 5_000

  # 作れなかったとき（モデルの確かめに通らなかったとき・知らない段階を指定したとき）に投げる
  class Error < StandardError; end

  # size：:small か :medium。作った数を返す（コマンドの最後に表示する）
  def self.load!(size)
    new(size).load!
  end

  # 測定用のアカウント（メールアドレスが bench- で始まる）
  def self.bench_users
    User.where("email LIKE ?", "#{EMAIL_PREFIX}%#{EMAIL_DOMAIN}")
  end

  def initialize(size)
    @counts = SIZES.fetch(size.to_sym) { raise Error, "段階は #{SIZES.keys.join('・')} のどれかを指定してください（指定：#{size}）" }
    @random = Random.new(RANDOM_SEED)
    @today = Time.zone.today
  end

  def load!
    without_sql_log do
      with_min_password_cost do
        load_masters
        ActiveRecord::Base.transaction do
          delete_previous!
          companies = create_companies!
          postings = create_postings!(companies)
          students = create_students!
          candidacy_count = create_applications!(students, postings)
          RecommendationStatsRebuildJob.perform_now
          { companies: companies.size, job_postings: postings.size, students: students.size, candidacies: candidacy_count }
        end
      end
    end
  end

  private

  # パスワードの暗号化（bcrypt）は、わざと時間のかかる計算にしてあり、標準の強さでは1人0.2〜0.3秒かかる。
  # 中の段階（5,000人超）ではそれだけで20分前後になるので、作るあいだだけ一番軽い強さにする（PR310）。
  # テストの環境で Rails がしているのと同じ設定。強さは暗号化した値の中に記録されるので、ログインはふつうにできる。
  # 作り終わったら元に戻すので、画面からの登録や仮のデータには影響しない
  def with_min_password_cost
    original = ActiveModel::SecurePassword.min_cost
    ActiveModel::SecurePassword.min_cost = true
    yield
  ensure
    ActiveModel::SecurePassword.min_cost = original
  end

  # 開発用の設定では、SQL を1本ずつログに書く（呼び出し元の行も調べる）。学生1人の登録でも数十本あり、
  # 中の段階では十数万本になって、書くだけで時間がかかるので、作るあいだは止める（PR309。測る処理と同じ）
  def without_sql_log
    logger = ActiveRecord::Base.logger
    original_level = logger&.level
    logger&.level = Logger::INFO
    yield
  ensure
    logger&.level = original_level if logger
  end

  # マスタの番号を、最初に1回だけ読んでおく（1件ずつ探しに行かない）。
  # 番号の順に並べる（乱数の種が同じなら、毎回同じものが選ばれるように）
  def load_masters
    @job_middle_category_ids = JobMiddleCategory.order(:id).ids
    @technology_ids = Technology.order(:id).ids
    @industry_ids = Industry.order(:id).ids
    @business_type_ids = BusinessType.order(:id).ids
    @work_process_ids = WorkProcess.order(:id).ids
    @prefecture_ids = Prefecture.order(:id).ids
  end

  # ── ① 前回の測定用のデータを消す ──
  # 仮のデータ（db/demo/loader.rb）と同じく、つながる側（子）から順に消す。
  # 測定用のアカウントで画面から操作した場合（スカウト・メッセージ・アイコン・ログイン）の分も消す
  def delete_previous!
    user_ids = self.class.bench_users.ids
    company_ids = CompanyProfile.where(user_id: user_ids).ids
    student_ids = StudentProfile.where(user_id: user_ids).ids
    posting_ids = JobPosting.where(company_profile_id: company_ids).ids
    candidacy_ids = Candidacy.where(job_posting_id: posting_ids).or(Candidacy.where(student_profile_id: student_ids)).ids
    thread_ids = MessageThread.where(company_profile_id: company_ids).or(MessageThread.where(student_profile_id: student_ids)).ids

    ScoutMessage.where(candidacy_id: candidacy_ids).delete_all
    Message.where(message_thread_id: thread_ids).delete_all
    CandidacyReason.where(candidacy_id: candidacy_ids).delete_all
    Candidacy.where(id: candidacy_ids).delete_all
    MessageThread.where(id: thread_ids).delete_all

    [ JobPostingJobCategory, JobPostingTechnology, JobPostingWorkProcess, JobPostingIndustry, JobPostingBusinessType,
      JobPostingRecommendationStat ].each do |model|
      model.where(job_posting_id: posting_ids).delete_all
    end
    JobPosting.where(id: posting_ids).delete_all

    [ CompanyIndustry, CompanyBusinessType ].each { |model| model.where(company_profile_id: company_ids).delete_all }
    [ StudentSkill, StudentInterestedJobCategory, StudentInterestedIndustry, StudentCommutablePrefecture,
      StudentRecommendationStat ].each do |model|
      model.where(student_profile_id: student_ids).delete_all
    end

    ActiveStorage::Attachment.where(record_type: "CompanyProfile", record_id: company_ids)
                             .or(ActiveStorage::Attachment.where(record_type: "StudentProfile", record_id: student_ids))
                             .find_each(&:purge)

    Session.where(user_id: user_ids).delete_all
    CompanyProfile.where(id: company_ids).delete_all
    StudentProfile.where(id: student_ids).delete_all
    User.where(id: user_ids).delete_all
  end

  # ── ② 企業 ──
  # 新規登録と同じ処理（CompanyRegistration）で作る。募集 POSTINGS_PER_COMPANY 件ごとに1社
  def create_companies!
    company_count = (@counts[:job_postings].to_f / POSTINGS_PER_COMPANY).ceil
    (1..company_count).map do |number|
      registration = CompanyRegistration.new({
        **account_attributes("company", number),
        name: "測定用企業#{number}",
        industry_ids: sample(@industry_ids, 1..2),
        business_type_ids: sample(@business_type_ids, 1..2)
      })
      check!(registration.save, registration, "測定用企業#{number}")
      registration.profile
    end
  end

  # ── ③ 募集 ──
  # 募集の保存の処理（save_posting）で、掲載中の募集を作る。最初に掲載した日時は、過去30日の中にばらす
  def create_postings!(companies)
    (1..@counts[:job_postings]).map do |number|
      company = companies[(number - 1) / POSTINGS_PER_COMPANY]
      posting = company.job_postings.new
      check!(posting.save_posting(posting_attributes(number)), posting, "測定用募集#{number}")
      time = @random.rand(1..30).days.ago
      posting.update_columns(created_at: time, updated_at: time, published_at: time)
      posting
    end
  end

  def posting_attributes(number)
    main_jobs, related_jobs = split_sample(@job_middle_category_ids, 1..2, 0..2)
    main_processes, involved_processes = split_sample(@work_process_ids, 1..2, 0..3)
    work_style = maybe { JobPosting.work_styles.keys.sample(random: @random) }
    {
      status: "published",
      title: "測定用募集#{number}",
      internship_details: "測定用の募集です。",
      hourly_wage: @random.rand(11..20) * 100,
      main_job_middle_category_ids: main_jobs,
      related_job_middle_category_ids: related_jobs,
      main_work_process_ids: main_processes,
      involved_work_process_ids: involved_processes,
      technology_ids: sample(@technology_ids, 2..4),
      industry_ids: sample(@industry_ids, 1..1),
      business_type_ids: sample(@business_type_ids, 1..1),
      **work_condition_attributes("min_work_days_per_week", "min_work_hours_per_day", "min_duration_months"),
      start_month: maybe { month_from_now(@random.rand(0..3)) },
      work_style: work_style,
      # フルリモートの募集は、勤務地を入れない
      prefecture_id: work_style == "full_remote" ? nil : maybe { @prefecture_ids.sample(random: @random) },
      weekend_ok: @random.rand < 0.5,
      **culture_attributes("culture")
    }
  end

  # ── ④ 学生 ──
  # 新規登録と同じ処理（StudentRegistration）で作り、最終活動日を30日以内にばらす（学生検索で外されないように）
  def create_students!
    activity_statuses = StudentProfile.activity_statuses.keys
    (1..@counts[:students]).map do |number|
      registration = StudentRegistration.new({
        **account_attributes("student", number),
        name: "測定用学生#{number}",
        activity_status: activity_statuses.sample(random: @random),
        **student_profile_attributes
      })
      check!(registration.save, registration, "測定用学生#{number}")
      registration.user.update_column(:last_active_on, @today - @random.rand(0..29))
      registration.profile
    end
  end

  def student_profile_attributes
    can_full_remote, can_partial_remote, can_onsite = remote_choices
    {
      interested_job_middle_category_ids: sample(@job_middle_category_ids, 1..3),
      interested_industry_ids: sample(@industry_ids, 0..2),
      skills: sample(@technology_ids, 1..5).map { |id| { technology_id: id, level: StudentSkill.levels.keys.sample(random: @random) } },
      **work_condition_attributes("work_days_per_week", "work_hours_per_day", "duration_months"),
      available_from: maybe { month_from_now(@random.rand(0..3)) },
      can_full_remote: can_full_remote,
      can_partial_remote: can_partial_remote,
      can_onsite: can_onsite,
      commutable_prefecture_ids: sample(@prefecture_ids, 0..3),
      **culture_attributes("personality")
    }
  end

  # 勤務形態の「可能」の3つ。6割の学生は3つとも可能（多くの学生がどれも可能なため。その他決め事.md の 5-6）。
  # 残りは乱数で選び、1つも可能でない組は作らない
  def remote_choices
    return [ true, true, true ] if @random.rand < 0.6

    loop do
      choices = Array.new(3) { @random.rand < 0.5 }
      return choices if choices.any?
    end
  end

  # ── ⑤ 応募 ──
  # 学生ごとに、applications_per_student 件の募集に応募する。応募先は、募集ごとの「人気」の重みで選ぶ（PR306）。
  # 募集を乱数で並べ、k 番目（0 から）の重みを 1 ÷ √(k + 1) にする。上位の募集ほど選ばれやすい。
  # 応募とその理由は insert_all でまとめて入れる（モデルの処理を通さないので、応募のジョブは積まれない）
  def create_applications!(students, postings)
    ranked_posting_ids = postings.map(&:id).shuffle(random: @random)
    cumulative = ranked_posting_ids.each_index.inject([]) { |sums, k| sums << (sums.last || 0.0) + 1.0 / Math.sqrt(k + 1) }
    per_student = [ @counts[:applications_per_student], ranked_posting_ids.size ].min

    reason_names = CandidacyReason.reasons.keys
    applications = students.flat_map do |student|
      pick_weighted(ranked_posting_ids, cumulative, per_student).map do |job_posting_id|
        [ student.id, job_posting_id, sample(reason_names, 1..3), @random.rand(0..(60 * 24 * 60)).minutes.ago ]
      end
    end

    applications.each_slice(INSERT_BATCH_SIZE) { |rows| insert_applications!(rows) }
    applications.size
  end

  # 重みを付けて、count 件を重複なしで選ぶ
  def pick_weighted(ids, cumulative, count)
    picked = []
    while picked.size < count
      point = @random.rand * cumulative.last
      id = ids[cumulative.bsearch_index { |sum| sum > point }]
      picked << id unless picked.include?(id)
    end
    picked
  end

  # rows：[学生の番号, 募集の番号, 理由の名前の一覧, 応募した日時] の一覧。
  # やりとりを入れて番号を受け取り（returning）、その番号で応募理由を入れる。
  # 理由の組の写し（reason_mask）も、モデルの応募（Candidacy.apply）と同じ計算で一緒に入れる
  def insert_applications!(rows)
    candidacy_rows = rows.map do |student_id, job_posting_id, reasons, applied_at|
      { student_profile_id: student_id, job_posting_id: job_posting_id,
        origin: Candidacy.origins.fetch("application"), status: Candidacy.statuses.fetch("unmatched"),
        reason_mask: CandidacyReason.mask_for(reasons), created_at: applied_at, updated_at: applied_at }
    end
    inserted = Candidacy.insert_all!(candidacy_rows, returning: %w[id student_profile_id job_posting_id])
    candidacy_ids = inserted.rows.to_h { |id, student_id, job_posting_id| [ [ student_id, job_posting_id ], id ] }

    reason_rows = rows.flat_map do |student_id, job_posting_id, reasons, applied_at|
      candidacy_id = candidacy_ids.fetch([ student_id, job_posting_id ])
      reasons.map do |reason|
        { candidacy_id: candidacy_id, reason: CandidacyReason.reasons.fetch(reason), created_at: applied_at, updated_at: applied_at }
      end
    end
    CandidacyReason.insert_all!(reason_rows)
  end

  # ── 小さな道具 ──

  # 測定用のアカウントのメールアドレスとパスワード（例：bench-student3@example.com）
  def account_attributes(kind, number)
    { email: "#{EMAIL_PREFIX}#{kind}#{number}#{EMAIL_DOMAIN}", password: PASSWORD, password_confirmation: PASSWORD }
  end

  # 番号の一覧から、range の範囲の個数を重複なしで選ぶ
  def sample(ids, range)
    ids.sample(@random.rand(range), random: @random)
  end

  # 主・関連（メイン・関われる）のように、重ならない2つの組を選ぶ
  def split_sample(ids, first_range, second_range)
    first = sample(ids, first_range)
    [ first, sample(ids - first, second_range) ]
  end

  # BLANK_RATE の割合で空欄（nil）、それ以外はブロックの値
  def maybe
    @random.rand < BLANK_RATE ? nil : yield
  end

  # 稼働条件の3つの数値。選択肢（concerns/work_conditions.rb）から選び、一部は空欄にする
  def work_condition_attributes(days, hours, months)
    {
      days => maybe { WorkConditions::WORK_DAYS_PER_WEEK.sample(random: @random) },
      hours => maybe { WorkConditions::WORK_HOURS_PER_DAY.sample(random: @random) },
      months => maybe { WorkConditions::DURATION_MONTHS.sample(random: @random) }
    }.symbolize_keys
  end

  # カルチャー（募集）・働き方の好み（学生）の5軸。−2〜2
  def culture_attributes(prefix)
    CultureAxes::AXES.to_h { |axis| [ :"#{prefix}_#{axis}", @random.rand(CultureAxes::MIN..CultureAxes::MAX) ] }
  end

  # 今月から offset か月後の、月の1日
  def month_from_now(offset)
    @today.beginning_of_month.advance(months: offset)
  end

  # 保存できなかったら、どこで何が足りなかったかを添えて止める（トランザクションごと取り消される）
  def check!(saved, record, label)
    return if saved

    raise Error, "#{label}を作れませんでした：#{record.errors.full_messages.join('、')}"
  end
end
