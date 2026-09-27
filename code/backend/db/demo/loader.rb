# 仮のデータ（デモ用）を作る処理。中身は db/demo/content.rb。
# 入口はコマンド bin/rails demo:load（lib/tasks/demo.rake。bash dev.sh demo からも呼べる）。
#
# - 何度実行しても同じ状態になるよう、前回の仮のデータを消してから作り直す（PR264）。
#   仮のデータは、メールアドレスが demo- で始まるアカウントと、それにつながるもの。試しのアカウントや手で登録したアカウントは消さない
# - 作るときは、画面の操作と同じモデルの処理（新規登録・募集の保存・応募・スカウト・マッチ・メッセージの送信）を通す（PR266）。
#   ありえない状態のデータ（スカウトなのに応募理由がある、など）ができないようにするため
# - 組み合わせに使う乱数は種を固定し、毎回同じ結果にする（PR265）
# - 全体を1つのトランザクションで行う。途中で1つでも確かめに通らなければ、すべて取り消して、どこで止まったかを出す
require_relative "content"

class DemoLoader
  # 仮のアカウントのメールアドレス（demo-company1@example.com、demo-student1@example.com …）とパスワード
  EMAIL_PREFIX = "demo-"
  EMAIL_DOMAIN = "@example.com"
  PASSWORD = "password"
  # 乱数の種。変えると、募集の掲載日のばらけ方が変わる
  RANDOM_SEED = 20_260_927

  # 作れなかったとき（モデルの確かめに通らなかったとき）に投げる
  class Error < StandardError; end

  # 作った数を返す（コマンドの最後に表示する）
  def self.load!
    new.load!
  end

  def initialize
    @random = Random.new(RANDOM_SEED)
    @today = Time.zone.today
  end

  def load!
    ActiveRecord::Base.transaction do
      delete_previous!
      @companies = create_companies!
      @postings = create_postings!
      @students = create_students!
      create_applications!
      create_scouts!
      create_messages!
    end
    { companies: @companies.size, job_postings: @postings.size, students: @students.size,
      candidacies: DemoContent::APPLICATIONS.size + DemoContent::SCOUTS.size }
  end

  # 仮のアカウントか（メールアドレスが demo- で始まる）。Django の filter(email__startswith="demo-") にあたる
  def self.demo_users
    User.where("email LIKE ?", "#{EMAIL_PREFIX}%#{EMAIL_DOMAIN}")
  end

  private

  # ── ① 前回の仮のデータを消す ──
  # 外部キーでつながっているので、つながる側（子）から順に消す。
  # delete_all はモデルの処理を通さず、SQL の DELETE を1回送る（Django の QuerySet.delete() に近い）
  def delete_previous!
    user_ids = self.class.demo_users.ids
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

    [ JobPostingJobCategory, JobPostingTechnology, JobPostingWorkProcess, JobPostingIndustry, JobPostingBusinessType ].each do |model|
      model.where(job_posting_id: posting_ids).delete_all
    end
    JobPosting.where(id: posting_ids).delete_all

    [ CompanyIndustry, CompanyBusinessType ].each { |model| model.where(company_profile_id: company_ids).delete_all }
    [ StudentSkill, StudentInterestedJobCategory, StudentInterestedIndustry, StudentCommutablePrefecture ].each do |model|
      model.where(student_profile_id: student_ids).delete_all
    end

    # 画面から仮のアカウントにアイコンを付けていた場合は、ファイルごと消す
    ActiveStorage::Attachment.where(record_type: "CompanyProfile", record_id: company_ids)
                             .or(ActiveStorage::Attachment.where(record_type: "StudentProfile", record_id: student_ids))
                             .find_each(&:purge)

    Session.where(user_id: user_ids).delete_all
    CompanyProfile.where(id: company_ids).delete_all
    StudentProfile.where(id: student_ids).delete_all
    User.where(id: user_ids).delete_all
  end

  # ── ② 企業 ──
  # 新規登録と同じ処理（CompanyRegistration）で、アカウントとプロフィールを作る。返すもの：{ key => 企業プロフィール }
  def create_companies!
    DemoContent::COMPANIES.each.with_index(1).to_h do |row, number|
      registration = CompanyRegistration.new({
        **account_attributes("company", number),
        name: row[:name],
        employee_size: row[:employee_size],
        about: row[:about],
        business_description: row[:business_description],
        industry_ids: master_ids(Industry, row[:industries]),
        business_type_ids: master_ids(BusinessType, row[:business_types])
      })
      check!(registration.save, registration, "企業「#{row[:name]}」")
      [ row[:key], registration.profile ]
    end
  end

  # ── ③ 募集 ──
  # 募集の保存の処理（save_posting）で作る。返すもの：{ key => 募集 }
  def create_postings!
    DemoContent::POSTINGS.to_h do |row|
      company = @companies.fetch(row[:company])
      posting = company.job_postings.new
      label = "募集「#{row[:title]}」"
      # 新規作成では終了を選べない（権限_バリデーション.md の 17-2-2）ので、終了の募集は掲載中で作ってから終了にする
      first_status = row[:status] == :closed ? "published" : row[:status].to_s
      check!(posting.save_posting(posting_attributes(row, company).merge(status: first_status)), posting, label)
      check!(posting.save_posting(status: "closed"), posting, label) if row[:status] == :closed
      spread_timestamps(posting)
      [ row[:key], posting ]
    end
  end

  def posting_attributes(row, company)
    main_jobs, related_jobs = row[:jobs]
    main_processes, involved_processes = row[:processes]
    pace, novelty, collaboration, decision, atmosphere = row[:culture]
    {
      title: row[:title],
      internship_details: row[:internship_details],
      growth: row[:growth],
      requirements: row[:requirements],
      preferred_requirements: row[:preferred_requirements],
      main_job_middle_category_ids: job_category_ids(main_jobs),
      related_job_middle_category_ids: job_category_ids(related_jobs),
      main_work_process_ids: master_ids(WorkProcess, main_processes),
      involved_work_process_ids: master_ids(WorkProcess, involved_processes),
      technology_ids: master_ids(Technology, row[:technologies]),
      # 募集の業界・事業形態は、その会社と同じものにする（募集ごとに持つ値。その他決め事.md の 5-8）
      industry_ids: company.industry_ids,
      business_type_ids: company.business_type_ids,
      hourly_wage: row[:hourly_wage],
      min_work_days_per_week: row[:days],
      min_work_hours_per_day: row[:hours],
      min_duration_months: row[:months],
      start_month: row[:start_month] && month_from_now(row[:start_month]),
      work_style: row[:work_style],
      work_style_note: row[:work_style_note],
      prefecture_id: row[:prefecture] && Prefecture.find_by!(name: row[:prefecture]).id,
      work_location_note: row[:work_location_note],
      weekend_ok: row[:weekend_ok],
      work_note: row[:work_note],
      culture_pace: pace,
      culture_novelty: novelty,
      culture_collaboration: collaboration,
      culture_decision: decision,
      culture_atmosphere: atmosphere
    }
  end

  # 作った日・最終更新日・最初に掲載した日を、過去30日の中にばらけさせる（新着順・最終更新順の並びが意味を持つように）。
  # update_columns はモデルの処理を通さず、その列だけを書き換える
  def spread_timestamps(posting)
    time = @random.rand(1..30).days.ago
    posting.update_columns(created_at: time, updated_at: time, published_at: posting.published_at && time)
  end

  # ── ④ 学生 ──
  # 新規登録と同じ処理（StudentRegistration）で作り、最終活動日を入れる。返すもの：[学生プロフィール, …]（STUDENTS と同じ順）
  def create_students!
    DemoContent::STUDENTS.each.with_index(1).map do |row, number|
      attributes = { **account_attributes("student", number), name: row[:name], activity_status: row[:activity_status] }
      attributes.merge!(student_profile_attributes(row)) unless row[:minimal]
      registration = StudentRegistration.new(attributes)
      check!(registration.save, registration, "学生「#{row[:name]}」")
      # 最終活動日（その他決め事.md の 5-4）。30日より前の学生は、学生検索に出ない
      registration.user.update_column(:last_active_on, @today - row[:active])
      registration.profile
    end
  end

  def student_profile_attributes(row)
    type = DemoContent::STUDENT_TYPES.fetch(row[:type])
    profile = type[:profiles].fetch(row[:profile])
    faculty = Faculty.find_by!(name: row[:faculty])
    days, hours, months, available_from = row[:work]
    can_full_remote, can_partial_remote, can_onsite = row[:remote]
    pace, novelty, collaboration, decision, atmosphere = row[:personality]
    {
      university_id: University.find_by!(name: row[:university]).id,
      faculty_id: faculty.id,
      department_id: faculty.departments.find_by!(name: row[:department]).id,
      grade: row[:grade],
      graduation_year: row[:graduation_year],
      prefecture_id: Prefecture.find_by!(name: row[:prefecture]).id,
      self_pr_strength: profile[:strength],
      self_pr_weakness: profile[:weakness],
      self_pr_future: profile[:future],
      interested_job_middle_category_ids: job_category_ids(type[:jobs]),
      interested_industry_ids: master_ids(Industry, type[:industries]),
      work_days_per_week: days,
      work_hours_per_day: hours,
      duration_months: months,
      available_from: available_from && month_from_now(available_from),
      can_full_remote: can_full_remote,
      can_partial_remote: can_partial_remote,
      can_onsite: can_onsite,
      commutable_prefecture_ids: master_ids(Prefecture, row[:commutable]),
      personality_pace: pace,
      personality_novelty: novelty,
      personality_collaboration: collaboration,
      personality_decision: decision,
      personality_atmosphere: atmosphere,
      skills: profile[:skills].map { |name, years, level| skill_row(name, years, level) }
    }
  end

  # プログラミング歴の1行。技術のマスタにある名前なら技術の番号、なければ「その他」の名前にする
  def skill_row(name, years, level)
    technology = Technology.find_by(name: name)
    { technology_id: technology&.id, other_name: technology ? nil : name, years: years, level: level }
  end

  # ── ⑤ やりとりとメッセージ ──

  # 応募（Candidacy.apply）。matched なら、そのあと企業がマッチする（match）
  def create_applications!
    DemoContent::APPLICATIONS.each do |row|
      student = student_at(row[:student])
      posting = @postings.fetch(row[:posting])
      candidacy = Candidacy.apply(student, posting, row[:reasons])
      check!(candidacy.persisted?, candidacy, "#{student.name}さんの「#{posting.title}」への応募")
      candidacy.match if row[:matched]
    end
  end

  # スカウト（Candidacy.send_scout）。reasons があれば、そのあと学生がマッチする（match_by_student）
  def create_scouts!
    DemoContent::SCOUTS.each do |row|
      student = student_at(row[:student])
      posting = @postings.fetch(row[:posting])
      label = "「#{posting.title}」から#{student.name}さんへのスカウト"
      candidacy = Candidacy.send_scout(posting, student, scout_body(posting, student))
      check!(candidacy.persisted?, candidacy, label)
      check!(candidacy.match_by_student(row[:reasons]), candidacy, "#{label}へのマッチ") if row[:reasons]
    end
  end

  def scout_body(posting, student)
    first_skill = student.student_skills.first
    skill = first_skill && (first_skill.technology&.name || first_skill.other_name)
    format(DemoContent::SCOUT_BODY,
           last_name: student.name.split.first, company: posting.company_profile.name,
           title: posting.title, skill: skill || "プログラミング")
  end

  # マッチした組（企業×学生）ごとに、メッセージを2〜4通送る（スレッドの post_message）。
  # 通数は組ごとに変え、一覧の見え方に差をつける
  def create_messages!
    matched = Candidacy.after_match.where(job_posting_id: @postings.values.map(&:id)).includes(job_posting: { company_profile: :user })
    matched.order(:id).each_with_index do |candidacy, index|
      company = candidacy.job_posting.company_profile
      student = candidacy.student_profile
      thread = MessageThread.find_by!(company_profile: company, student_profile: student)
      DemoContent::MESSAGES.first(2 + (index % 3)).each do |row|
        sender = row[:from] == :company ? company.user : student.user
        message = thread.post_message(sender, format(row[:body], company: company.name))
        check!(message.persisted?, message, "#{company.name}と#{student.name}さんのメッセージ")
      end
    end
  end

  # ── 小さな道具 ──

  # 仮のアカウントのメールアドレスとパスワード（例：demo-student3@example.com）
  def account_attributes(kind, number)
    { email: "#{EMAIL_PREFIX}#{kind}#{number}#{EMAIL_DOMAIN}", password: PASSWORD, password_confirmation: PASSWORD }
  end

  # マスタの名前の一覧を、番号の一覧に直す。名前がマスタになければ止める（db/seeds.rb と content.rb の食い違いにすぐ気づくため）
  def master_ids(model, names)
    names.map { |name| model.find_by!(name: name).id }
  end

  # 職種の中分類のコードの一覧を、番号の一覧に直す
  def job_category_ids(codes)
    codes.map { |code| JobMiddleCategory.find_by!(code: code).id }
  end

  # 今月から offset か月後の、月の1日（開始時期は月の1日の日付。その他決め事.md の 5-6）
  def month_from_now(offset)
    @today.beginning_of_month.advance(months: offset)
  end

  # STUDENTS の何番目か（1から数える）の学生
  def student_at(number)
    @students.fetch(number - 1)
  end

  # 保存できなかったら、どこで何が足りなかったかを添えて止める（トランザクションごと取り消される）
  def check!(saved, record, label)
    return if saved

    raise Error, "#{label}を作れませんでした：#{record.errors.full_messages.join('、')}"
  end
end
