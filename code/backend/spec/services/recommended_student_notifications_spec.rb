require "rails_helper"

# 「おすすめの学生」の通知を作る部品（app/services/recommended_student_notifications.rb）のテスト。
# 詳しくは design/designs/処理設計_類似度.md の 7-3「ポップアップ・通知の取り方」、ページ設計.md の 6-5 C10。
# 似た募集のテスト（similar_job_postings_spec.rb）と同じく、応募がない（行動の近さの重みが0）ので、近さ f は内容の近さだけになる。
# Ruby を使う募集どうしは 0.25（技術）+ 0.10（カルチャー。5軸すべて中央で一致）= 0.35、それ以外は 0.10
RSpec.describe RecommendedStudentNotifications do
  let(:ruby) { create(:technology) }
  # 稼働条件は「週3日まで」だけ。週3日以下で働ける募集が合う
  let(:student) { create(:student_user).student_profile.tap { |s| s.update!(work_days_per_week: 3) } }
  # 学生が応募・マッチした募集
  let(:job_posting) { create_posting(technology_ids: [ ruby.id ]) }

  # 掲載中の募集。会社を指定しなければ、募集ごとに別の会社を作る
  def create_posting(company: create(:company_user).company_profile, technology_ids: [], **attributes)
    create(:job_posting, :published, company_profile: company, **attributes).tap do |posting|
      posting.save_posting(technology_ids: technology_ids) if technology_ids.any?
    end
  end

  # 学生・募集をすべて作ってから、推薦の集計（項目数）を作り直して通知を作る
  def notify
    student
    job_posting
    RecommendationStatsRebuildJob.perform_now
    described_class.create_for(student, job_posting)
  end

  def user_of(posting)
    posting.company_profile.user_id
  end

  it "稼働条件に合う会社が先。f が低くても、合わない会社より前に来る。合わない会社は f の高い順に続く。中身は学生・募集ごとの本文とリンク先" do
    matched_near = create_posting(min_work_days_per_week: 3, technology_ids: [ ruby.id ])
    matched_far = create_posting(min_work_days_per_week: 2)
    unmatched_near = create_posting(min_work_days_per_week: 5, technology_ids: [ ruby.id ])
    unmatched_far = create_posting

    notifications = notify

    expect(notifications.map(&:user_id)).to eq(
      [ matched_near, matched_far, unmatched_near, unmatched_far ].map { |posting| user_of(posting) }
    )
    expect(notifications.first.reload).to have_attributes(
      student_profile_id: student.id,
      kind: "recommended_student",
      body: "#{matched_near.title}に合いそうな学生がいます",
      link_path: "/company/students/#{student.id}?job_posting_id=#{matched_near.id}",
      read_at: nil
    )
  end

  it "同じ会社の似た募集が2件あっても、通知は1件だけ。代表は、f が低くても稼働条件に合う募集" do
    company = create(:company_user).company_profile
    create_posting(company: company, min_work_days_per_week: 5, technology_ids: [ ruby.id ])
    matched_far = create_posting(company: company, min_work_days_per_week: 2)

    notifications = notify

    expect(notifications.size).to eq(1)
    expect(notifications.first.link_path).to eq("/company/students/#{student.id}?job_posting_id=#{matched_far.id}")
  end

  it "応募した会社自身のほかの募集（PR321）、掲載中でない募集、学生とやりとりがある募集、この学生の通知をもう受け取った会社（PR322）には送らない。ほかの学生の通知だけを受け取った会社には送る" do
    create_posting(company: job_posting.company_profile)
    create(:job_posting)
    create(:job_posting, :closed)
    create(:candidacy, job_posting: create_posting, student_profile: student)
    notified = create_posting
    create(:notification, user: notified.company_profile.user, student_profile: student)
    notified_about_other = create_posting
    create(:notification, user: notified_about_other.company_profile.user)
    plain = create_posting

    expect(notify.map(&:user_id)).to contain_exactly(user_of(notified_about_other), user_of(plain))
  end

  it "最大5社。f が同じなら、新着順（最初に掲載した日時の新しい順）→ 番号の大きい順" do
    published_at = ->(days_ago) { Time.current.beginning_of_day - days_ago.days }
    day3 = create_posting.tap { |p| p.update_columns(published_at: published_at.(3)) }
    day1_first = create_posting.tap { |p| p.update_columns(published_at: published_at.(1)) }
    day1_second = create_posting.tap { |p| p.update_columns(published_at: published_at.(1)) }
    day2 = create_posting.tap { |p| p.update_columns(published_at: published_at.(2)) }
    day4 = create_posting.tap { |p| p.update_columns(published_at: published_at.(4)) }
    create_posting.tap { |p| p.update_columns(published_at: published_at.(5)) }

    expect(notify.map(&:user_id)).to eq(
      [ day1_second, day1_first, day2, day3, day4 ].map { |posting| user_of(posting) }
    )
    expect(Notification.count).to eq(5)
  end

  it "30日以上活動のない学生なら、通知を1件も作らない" do
    create_posting
    student.user.update!(last_active_on: Time.zone.today - 31)

    expect(notify).to eq([])
    expect(Notification.count).to eq(0)
  end
end
