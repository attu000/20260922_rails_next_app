require "rails_helper"
require Rails.root.join("db/demo/loader").to_s

# 仮のデータ（db/demo/loader.rb と content.rb）のテスト。
# 仮のデータが、今のモデルの確かめをすべて通って作れること（モデルの決まりを変えたときに、仮のデータの直し忘れに気づくため）と、
# 何度入れても同じ状態になり、仮のデータでないものは消さないこと（PR264）
RSpec.describe DemoLoader do
  # テストのデータベースにはマスタが入っていないので、db/seeds.rb を先に流す（試しのアカウントも一緒にできる）
  before { Rails.application.load_seed }

  def demo_counts
    user_ids = described_class.demo_users.ids
    company_ids = CompanyProfile.where(user_id: user_ids).ids
    student_ids = StudentProfile.where(user_id: user_ids).ids
    posting_ids = JobPosting.where(company_profile_id: company_ids).ids
    {
      companies: company_ids.size,
      job_postings: posting_ids.size,
      published: JobPosting.where(id: posting_ids).published.count,
      students: student_ids.size,
      candidacies: Candidacy.where(job_posting_id: posting_ids).count,
      matched: Candidacy.where(job_posting_id: posting_ids).after_match.count
    }
  end

  it "企業5社・募集20件（掲載中16件）・学生20人・やりとり18件（マッチ7件）を作り、マッチした組にはメッセージがある" do
    result = described_class.load!

    expect(result).to eq(companies: 5, job_postings: 20, students: 20, candidacies: 18)
    expect(demo_counts).to eq(companies: 5, job_postings: 20, published: 16, students: 20, candidacies: 18, matched: 7)
    # マッチした組（企業×学生）ごとに2〜4通。スカウト文もメッセージとしてスレッドに入るので、それは除いて数える
    thread_message_counts = Message.where.not(id: ScoutMessage.select(:message_id)).group(:message_thread_id).count.values
    expect(thread_message_counts.size).to eq(7)
    expect(thread_message_counts).to all(be_between(2, 4))
  end

  it "2回続けて入れても数は増えず、仮のデータでないアカウントは消えない" do
    other_student = create(:student_user).student_profile

    described_class.load!
    described_class.load!

    expect(demo_counts).to eq(companies: 5, job_postings: 20, published: 16, students: 20, candidacies: 18, matched: 7)
    expect(StudentProfile.exists?(other_student.id)).to be(true)
    # db/seeds.rb の試しのアカウントも残る
    expect(User.exists?(email: "company@example.com")).to be(true)
    expect(User.exists?(email: "student@example.com")).to be(true)
  end
end
