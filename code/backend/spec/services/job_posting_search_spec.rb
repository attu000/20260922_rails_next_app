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
  end

  describe "① フリーワード" do
    it "7項目のそれぞれで合う。大文字と小文字は区別しない" do
      by_title = create_posting(title: "Ruby の募集")
      by_details = create_posting(internship_details: "Ruby で開発します")
      by_requirements = create_posting(requirements: "Ruby の経験")
      by_preferred = create_posting(preferred_requirements: "Ruby 歓迎")
      by_technology_note = create_posting(technology_note: "Ruby 3.4")
      by_company = create(:job_posting, :published)
      by_company.company_profile.update!(name: "Ruby 株式会社")
      by_technology = create_posting
      by_technology.technologies << create(:technology, name: "Ruby on Rails")
      create_posting(title: "Go の募集")

      expect(matched_ids(q: "ruby")).to contain_exactly(
        by_title.id, by_details.id, by_requirements.id, by_preferred.id,
        by_technology_note.id, by_company.id, by_technology.id
      )
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
