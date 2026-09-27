require "rails_helper"

# 募集検索の本体（app/services/job_posting_search.rb）のテスト。
# 条件で結果を減らさず、指定した条件を全部満たすものを合致、1つでも外れるものを合致外にする。
# 詳しくは design/designs/API設計.md の 16-3 ⑱、処理設計_類似度.md の 7-3、その他決め事.md の 5-10
RSpec.describe JobPostingSearch do
  let(:student) { create(:student_user).student_profile }
  let(:company) { create(:company_user).company_profile }

  def search(params = {})
    JobPostingSearch.new(student: student, params: params)
  end

  # 条件に合う募集の番号（掲載中の募集すべての中から）
  def matched_ids(params)
    search(params).matched_ids_in(JobPosting.ids)
  end

  def create_posting(**attributes)
    create(:job_posting, :published, company_profile: company, **attributes)
  end

  describe "対象" do
    it "掲載中の募集だけを並べ、条件がなければ全件が合致" do
      published = create_posting
      create(:job_posting, company_profile: company)
      create(:job_posting, :closed, company_profile: company)
      create(:job_posting, :unpublished_after_published, company_profile: company)

      result = search

      expect(result.ordered.map(&:id)).to eq([ published.id ])
      expect(result.matched_count).to eq(1)
      expect(matched_ids({})).to eq([ published.id ])
    end

    # 募集管理に載っている募集は出さない（PR253）
    it "自分が応募した募集（見送られていても）とマッチした募集は出さない。スカウトありの募集と、ほかの学生が応募した募集は出す" do
      applied = create_posting
      create(:candidacy, job_posting: applied, student_profile: student)
      declined_application = create_posting
      create(:candidacy, job_posting: declined_application, student_profile: student, status: :declined)
      matched_scout = create_posting
      create(:candidacy, :scout, job_posting: matched_scout, student_profile: student, status: :matched)
      scouted = create_posting
      create(:candidacy, :scout, job_posting: scouted, student_profile: student)
      applied_by_other = create_posting
      create(:candidacy, job_posting: applied_by_other)

      result = search

      expect(result.ordered.map(&:id)).to contain_exactly(scouted.id, applied_by_other.id)
      expect(result.matched_count).to eq(2)
    end
  end

  describe "① フリーワード" do
    it "募集の文章の各列、会社名、使用技術の名前のそれぞれで合う。大文字と小文字は区別しない" do
      by_columns = {
        title: "Ruby の募集",
        internship_details: "Ruby で開発します",
        growth: "Ruby に詳しくなれます",
        work_style_note: "Ruby 勉強会の日は出社",
        work_location_note: "Ruby ビル 3階",
        work_note: "Ruby 会議の週は休み",
        requirements: "Ruby の経験",
        preferred_requirements: "Ruby 歓迎",
        technology_note: "Ruby 3.4"
      }.map { |column, text| create_posting(column => text) }
      by_company = create(:job_posting, :published)
      by_company.company_profile.update!(name: "Ruby 株式会社")
      by_technology = create_posting
      by_technology.technologies << create(:technology, name: "Ruby on Rails")
      create_posting(title: "Go の募集")

      expect(matched_ids(q: "ruby")).to contain_exactly(*by_columns.map(&:id), by_company.id, by_technology.id)
    end

    it "職種の名前で合う。中分類の名前でも、大分類の名前でも。説明文には反応しない" do
      web = create(:job_major_category, name: "Web・アプリ開発")
      backend = create(:job_middle_category, job_major_category: web, name: "バックエンド")
      data = create(:job_middle_category, name: "データ分析", description: "Web のアクセスを分析する")
      as_main = create_posting.tap { |p| p.job_posting_job_categories.create!(job_middle_category: backend, role: :main) }
      as_related = create_posting.tap { |p| p.job_posting_job_categories.create!(job_middle_category: backend, role: :related) }
      create_posting.tap { |p| p.job_posting_job_categories.create!(job_middle_category: data, role: :main) }

      # 中分類の名前
      expect(matched_ids(q: "バックエンド")).to contain_exactly(as_main.id, as_related.id)
      # 大分類の名前（その中の中分類を持つ募集）。「データ分析」の説明文にある「Web」には反応しない
      expect(matched_ids(q: "web")).to contain_exactly(as_main.id, as_related.id)
    end

    it "どんな会社か・事業内容は、募集に書いてあれば募集の文章で探す" do
      about = create_posting(about: "Ruby が得意な会社です")
      business = create_posting(business_description: "Ruby の受託開発")
      create_posting

      expect(matched_ids(q: "ruby")).to contain_exactly(about.id, business.id)
    end

    it "どんな会社か・事業内容が募集で空欄なら、企業プロフィールの文章で探す" do
      company.update!(about: "Ruby が得意な会社です", business_description: "Ruby の受託開発")
      both_blank = create_posting(about: nil, business_description: nil)

      expect(matched_ids(q: "ruby")).to eq([ both_blank.id ])
    end

    it "募集に書いてあるときは、画面に出ない企業プロフィールの文章では合わない" do
      company.update!(about: "Ruby が得意な会社です", business_description: "Ruby の受託開発")
      create_posting(about: "Go が得意な会社です", business_description: "Go の受託開発")

      expect(matched_ids(q: "ruby")).to eq([])
    end

    it "全角の空白で区切った2語は、両方を含む募集だけが合う" do
      both = create_posting(title: "Ruby と Go")
      create_posting(title: "Ruby だけ")

      expect(matched_ids(q: "ruby　go")).to eq([ both.id ])
    end

    it "% は「何でも」ではなく、ただの文字として探す" do
      percent = create_posting(title: "成長率100%")
      create_posting(title: "社員100人")

      expect(matched_ids(q: "100%")).to eq([ percent.id ])
    end

    it "空白だけなら、指定なし（全件が合致）" do
      posting = create_posting

      expect(matched_ids(q: " 　")).to eq([ posting.id ])
    end
  end

  describe "② 勤務地" do
    let(:tokyo) { create(:prefecture) }
    let(:osaka) { create(:prefecture) }

    it "選んだ県の募集と、フルリモートの募集が合う。勤務地が空欄の募集は合わない" do
      in_tokyo = create_posting(work_style: :onsite, prefecture: tokyo)
      create_posting(work_style: :onsite, prefecture: osaka)
      full_remote = create_posting(work_style: :full_remote, prefecture: nil)
      create_posting(work_style: :partial_remote, prefecture: nil)

      expect(matched_ids(prefecture_ids: [ tokyo.id ])).to contain_exactly(in_tokyo.id, full_remote.id)
    end
  end

  describe "④ 職種" do
    let(:major) { create(:job_major_category) }
    let(:middle_in_major) { create(:job_middle_category, job_major_category: major) }
    let(:other_middle) { create(:job_middle_category) }
    let!(:as_main) { create_posting.tap { |p| p.job_posting_job_categories.create!(job_middle_category: middle_in_major, role: :main) } }
    let!(:as_related) { create_posting.tap { |p| p.job_posting_job_categories.create!(job_middle_category: middle_in_major, role: :related) } }
    let!(:other) { create_posting.tap { |p| p.job_posting_job_categories.create!(job_middle_category: other_middle, role: :main) } }
    let!(:none) { create_posting }

    it "中分類は、主な職種でも関連する職種でも合う" do
      expect(matched_ids(job_middle_category_ids: [ middle_in_major.id ])).to contain_exactly(as_main.id, as_related.id)
    end

    it "大分類だけ選ぶと、その中の中分類を持つ募集が合う" do
      expect(matched_ids(job_major_category_ids: [ major.id ])).to contain_exactly(as_main.id, as_related.id)
    end

    it "大分類と中分類を両方送ると、どちらかに当てはまれば合う" do
      ids = matched_ids(job_major_category_ids: [ major.id ], job_middle_category_ids: [ other_middle.id ])

      expect(ids).to contain_exactly(as_main.id, as_related.id, other.id)
    end
  end

  describe "④ 使用技術" do
    it "選んだ技術のどれか1つを使う募集が合う。どれも使わない募集、技術なしの募集は合わない" do
      javascript = create(:technology, name: "JavaScript")
      typescript = create(:technology, name: "TypeScript")
      go = create(:technology, name: "Go")
      uses_javascript = create_posting.tap { |p| p.technologies << javascript }
      uses_both = create_posting.tap { |p| p.technologies << [ javascript, typescript ] }
      create_posting.tap { |p| p.technologies << go }
      create_posting

      ids = matched_ids(technology_ids: [ javascript.id, typescript.id ])

      expect(ids).to contain_exactly(uses_javascript.id, uses_both.id)
    end
  end

  # 順9 で足した条件（PR251）
  describe "④ 工程" do
    it "選んだ工程のどれかを、メインか関われるに持つ募集が合う。持たない募集・工程なしの募集は合わない" do
      design = create(:work_process, name: "設計")
      requirements = create(:work_process, name: "企画・要件定義")
      implementation = create(:work_process, name: "実装")
      as_main = create_posting.tap { |p| p.job_posting_work_processes.create!(work_process: design, role: :main) }
      as_involved = create_posting.tap do |p|
        p.job_posting_work_processes.create!(work_process: implementation, role: :main)
        p.job_posting_work_processes.create!(work_process: requirements, role: :involved)
      end
      create_posting.tap { |p| p.job_posting_work_processes.create!(work_process: implementation, role: :main) }
      create_posting

      ids = matched_ids(work_process_ids: [ design.id, requirements.id ])

      expect(ids).to contain_exactly(as_main.id, as_involved.id)
    end
  end

  describe "③ 稼働条件（PR200）" do
    # 学生が「3まで」を選ぶと、募集の下限が3以下なら合う。空欄は合わない。
    # 募集の値は、それぞれの選択肢の中から、3より小さい・3・3より大きいものを使う（継続期間の選択肢に2はない）
    {
      work_days_per_week: [ :min_work_days_per_week, [ 2, 3, 4 ] ],
      work_hours_per_day: [ :min_work_hours_per_day, [ 2, 3, 4 ] ],
      duration_months: [ :min_duration_months, [ 1, 3, 6 ] ]
    }.each do |param_key, (column, (lower_value, equal_value, higher_value))|
      it "#{param_key}：募集の下限が選んだ値以下なら合う。大きい募集と空欄の募集は合わない" do
        lower = create_posting(column => lower_value)
        equal = create_posting(column => equal_value)
        create_posting(column => higher_value)
        create_posting(column => nil)

        expect(matched_ids(param_key => 3)).to contain_exactly(lower.id, equal.id)
      end
    end

    describe "開始時期" do
      include ActiveSupport::Testing::TimeHelpers

      # 今日を 2026年9月15日（日本時間）に固定する。「今月」は 2026年9月
      around { |example| travel_to(Time.zone.local(2026, 9, 15, 12)) { example.run } }

      it "随時・今月より前に始まった募集・働ける月以降に始まる募集が合う。働ける月より前に始まる募集は合わない" do
        anytime = create_posting(start_month: nil)
        already_started = create_posting(start_month: Date.new(2026, 8, 1))
        same_month = create_posting(start_month: Date.new(2026, 11, 1))
        later = create_posting(start_month: Date.new(2026, 12, 1))
        create_posting(start_month: Date.new(2026, 10, 1))

        expect(matched_ids(available_from: "2026-11-01")).to contain_exactly(
          anytime.id, already_started.id, same_month.id, later.id
        )
      end

      it "今月に始まる募集は「今月より前」ではないので、働ける月より前なら合わない" do
        create_posting(start_month: Date.new(2026, 9, 1))

        expect(matched_ids(available_from: "2026-11-01")).to eq([])
      end
    end

    it "勤務形態：募集の勤務形態が、選んだものに含まれれば合う。空欄は合わない" do
      partial = create_posting(work_style: :partial_remote)
      onsite = create_posting(work_style: :onsite)
      create_posting(work_style: :full_remote)
      create_posting(work_style: nil)

      expect(matched_ids(work_styles: %w[partial_remote onsite])).to contain_exactly(partial.id, onsite.id)
    end

    it "土日OK：true なら土日OK の募集だけが合う。false なら条件にしない" do
      weekend = create_posting(weekend_ok: true)
      weekday = create_posting(weekend_ok: false)

      expect(matched_ids(weekend_ok: "true")).to eq([ weekend.id ])
      expect(matched_ids(weekend_ok: "false")).to contain_exactly(weekend.id, weekday.id)
    end

    it "数でない・日付でない・知らない名前の値は、その条件を「指定なし」として扱う" do
      posting = create_posting(min_work_days_per_week: 5, start_month: Date.new(2030, 1, 1), work_style: :onsite)

      expect(matched_ids(work_days_per_week: "abc", available_from: "zzz", work_styles: [ "unknown" ])).to eq([ posting.id ])
    end
  end

  describe "条件の組み合わせ" do
    it "条件を全部満たすと合致、1つでも外れると合致外" do
      tokyo = create(:prefecture)
      both = create_posting(title: "Ruby", work_style: :onsite, prefecture: tokyo)
      create_posting(title: "Ruby", work_style: :onsite, prefecture: create(:prefecture))
      create_posting(title: "Go", work_style: :onsite, prefecture: tokyo)

      result = search(q: "ruby", prefecture_ids: [ tokyo.id ])

      expect(result.matched_ids_in(JobPosting.ids)).to eq([ both.id ])
      expect(result.matched_count).to eq(1)
    end
  end

  describe "並び方" do
    # 合致外の新しい募集（2日前）が、合致の古い募集（3日前）より新しい、という並びを作る
    let!(:old_matched) { create_posting(title: "Ruby 古い", published_at: 3.days.ago) }
    let!(:new_matched) { create_posting(title: "Ruby 新しい", published_at: 1.day.ago) }
    let!(:old_unmatched) { create_posting(title: "Go 古い", published_at: 4.days.ago) }
    let!(:new_unmatched) { create_posting(title: "Go 新しい", published_at: 2.days.ago) }
    let(:expected_ids) { [ new_matched.id, old_matched.id, new_unmatched.id, old_unmatched.id ] }

    it "新着順：合致の群（新しい順）→ 合致外の群（新しい順）。SQL で並べる" do
      ordered = search(q: "ruby", sort: "newest").ordered

      expect(ordered).to be_a(ActiveRecord::Relation)
      expect(ordered.map(&:id)).to eq(expected_ids)
    end

    it "おすすめ順：仮の点数は全件0点なので、新着順と同じ並び。Ruby の配列で並べる" do
      ordered = search(q: "ruby", sort: "recommended").ordered

      expect(ordered).to be_a(Array)
      expect(ordered.map(&:id)).to eq(expected_ids)
    end

    it "並び順を省いたときと、知らない値のときは、おすすめ順" do
      expect(search(q: "ruby").ordered).to be_a(Array)
      expect(search(q: "ruby", sort: "unknown").ordered).to be_a(Array)
    end
  end
end
