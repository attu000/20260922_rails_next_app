require "rails_helper"
require Rails.root.join("db/bench/loader").to_s

# 測定用のデータ（db/bench/loader.rb）のテスト。
# 今のモデルの確かめをすべて通って作れること、推薦の集計がそろうこと、
# 何度入れても同じ状態になり、測定用のデータでないものは消さないことを確かめる。件数は小さい数に差し替える
RSpec.describe BenchLoader do
  # テストのデータベースにはマスタが入っていないので、db/seeds.rb を先に流す（試しのアカウントも一緒にできる）
  before do
    Rails.application.load_seed
    stub_const("BenchLoader::SIZES", { small: { students: 4, job_postings: 12, applications_per_student: 3 } })
  end

  def bench_counts
    user_ids = described_class.bench_users.ids
    company_ids = CompanyProfile.where(user_id: user_ids).ids
    student_ids = StudentProfile.where(user_id: user_ids).ids
    posting_ids = JobPosting.where(company_profile_id: company_ids).ids
    {
      companies: company_ids.size,
      job_postings: posting_ids.size,
      published: JobPosting.where(id: posting_ids).published.count,
      students: student_ids.size,
      candidacies: Candidacy.where(student_profile_id: student_ids).count,
      posting_stats: JobPostingRecommendationStat.where(job_posting_id: posting_ids).count,
      student_stats: StudentRecommendationStat.where(student_profile_id: student_ids).count
    }
  end

  it "企業（募集10件ごとに1社）・掲載中の募集・学生・応募を指定の件数で作り、推薦の集計の行もそろう" do
    result = described_class.load!(:small)

    expect(result).to eq(companies: 2, job_postings: 12, students: 4, candidacies: 12)
    expect(bench_counts).to eq(companies: 2, job_postings: 12, published: 12, students: 4, candidacies: 12,
                               posting_stats: 12, student_stats: 4)
  end

  it "応募はどれも応募理由付きで、学生ごとに違う募集に応募し、推薦の集計の件数と一致する" do
    described_class.load!(:small)

    student_ids = StudentProfile.where(user_id: described_class.bench_users.select(:id)).ids
    candidacies = Candidacy.where(student_profile_id: student_ids)
    expect(candidacies.interests.count).to eq(12)
    expect(candidacies.group(:student_profile_id).distinct.count(:job_posting_id).values).to all(eq(3))
    # 理由の組の写し（reason_mask）が、応募理由の行と合っている
    candidacies.includes(:candidacy_reasons).find_each do |candidacy|
      expect(candidacy.reason_mask).to eq(CandidacyReason.mask_for(candidacy.reasons))
    end
    expect(StudentRecommendationStat.where(student_profile_id: student_ids).sum(:interest_count)).to eq(12)
  end

  it "学生は全員、最近（30日以内に）活動した学生に入る（学生検索で外されない）" do
    described_class.load!(:small)

    student_ids = StudentProfile.where(user_id: described_class.bench_users.select(:id)).ids
    expect(StudentProfile.recently_active.where(id: student_ids).count).to eq(4)
  end

  it "2回続けて入れても数は増えず、同じデータになる。測定用のデータでないアカウントは消えない" do
    other_student = create(:student_user).student_profile

    described_class.load!(:small)
    first_titles = JobPosting.where("title LIKE ?", "測定用募集%").order(:title).pluck(:title, :hourly_wage)
    described_class.load!(:small)

    expect(bench_counts).to eq(companies: 2, job_postings: 12, published: 12, students: 4, candidacies: 12,
                               posting_stats: 12, student_stats: 4)
    expect(JobPosting.where("title LIKE ?", "測定用募集%").order(:title).pluck(:title, :hourly_wage)).to eq(first_titles)
    expect(StudentProfile.exists?(other_student.id)).to be(true)
    # db/seeds.rb の試しのアカウントも残る
    expect(User.exists?(email: "company@example.com")).to be(true)
    expect(User.exists?(email: "student@example.com")).to be(true)
  end

  it "知らない段階を指定すると、Error で止める" do
    expect { described_class.load!(:huge) }.to raise_error(BenchLoader::Error, /段階は/)
  end
end
