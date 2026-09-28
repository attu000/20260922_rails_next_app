require "rails_helper"

# 計算に使う興味の一覧のテスト（design/designs/処理設計_類似度.md の 7-2「計算に使う興味の数の上限」。PR287）。
# 上限は、テストの中で小さい数に差し替えて確かめる（stub_const）
RSpec.describe Recommendation::Interests do
  let(:posting) { create(:job_posting, :published) }

  def create_student
    create(:student_user).student_profile
  end

  # 応募理由を付けた応募。応募した日時を at にする
  def apply(student, job_posting, at:)
    candidacy = create(:candidacy, student_profile: student, job_posting: job_posting)
    candidacy.save_reasons!(%w[business])
    candidacy.update_columns(created_at: at)
    candidacy
  end

  # SQL を実行して [募集の番号, 学生の番号] の一覧にする
  def pairs(sql)
    ActiveRecord::Base.connection.select_rows(sql).map { |job_posting_id, student_id, _mask| [ job_posting_id.to_i, student_id.to_i ] }
  end

  def postings_sql(*job_postings)
    described_class.of_postings_sql(JobPosting.where(id: job_postings.map(&:id)).select(:id).to_sql)
  end

  def students_sql(*students)
    described_class.of_students_sql(StudentProfile.where(id: students.map(&:id)).select(:id).to_sql)
  end

  describe ".of_postings_sql（募集ごとに新しい順に L_P 人まで）" do
    before { stub_const("Recommendation::Parameters::INTERESTS_PER_POSTING", 2) }

    it "応募した日時の新しい順に、上限の人数だけ返す" do
      oldest, middle, newest = Array.new(3) { create_student }
      apply(oldest, posting, at: Time.zone.parse("2026-09-01"))
      apply(middle, posting, at: Time.zone.parse("2026-09-02"))
      apply(newest, posting, at: Time.zone.parse("2026-09-03"))

      expect(pairs(postings_sql(posting))).to contain_exactly([ posting.id, middle.id ], [ posting.id, newest.id ])
    end

    it "スカウトは、届いた日時ではなくマッチした日時で並ぶ" do
      stub_const("Recommendation::Parameters::INTERESTS_PER_POSTING", 1)
      applicant = create_student
      scouted = create_student
      apply(applicant, posting, at: Time.zone.parse("2026-09-03"))
      # 9月1日に届いたスカウトに、9月5日に応じてマッチした
      scout = create(:candidacy, :scout, student_profile: scouted, job_posting: posting)
      scout.match_by_student(%w[culture])
      scout.update_columns(created_at: Time.zone.parse("2026-09-01"), matched_at: Time.zone.parse("2026-09-05"))

      expect(pairs(postings_sql(posting))).to eq([ [ posting.id, scouted.id ] ])
    end

    it "まだ応じていないスカウトは、興味に入れない" do
      create(:candidacy, :scout, job_posting: posting)

      expect(pairs(postings_sql(posting))).to eq([])
    end

    it "上限は募集ごとにかかる" do
      stub_const("Recommendation::Parameters::INTERESTS_PER_POSTING", 1)
      other_posting = create(:job_posting, :published)
      student = create_student
      apply(student, posting, at: Time.zone.parse("2026-09-01"))
      apply(student, other_posting, at: Time.zone.parse("2026-09-02"))

      expect(pairs(postings_sql(posting, other_posting))).to contain_exactly([ posting.id, student.id ], [ other_posting.id, student.id ])
    end
  end

  describe ".of_students_sql（学生ごとに新しい順に L_S 件まで）" do
    it "応募した日時の新しい順に、上限の件数だけ返す" do
      stub_const("Recommendation::Parameters::INTERESTS_PER_STUDENT", 1)
      student = create_student
      newer = create(:job_posting, :published)
      apply(student, posting, at: Time.zone.parse("2026-09-01"))
      apply(student, newer, at: Time.zone.parse("2026-09-02"))

      expect(pairs(students_sql(student))).to eq([ [ newer.id, student.id ] ])
    end
  end

  # 13-3a：Ruby の辞書で取り出す形
  describe ".postings_by_student と .students_by_posting" do
    let(:other_posting) { create(:job_posting, :published) }
    let(:student) { create_student }
    let(:other_student) { create_student }

    before do
      apply(student, posting, at: Time.zone.parse("2026-09-01"))
      apply(student, other_posting, at: Time.zone.parse("2026-09-02"))
      apply(other_student, posting, at: Time.zone.parse("2026-09-03"))
    end

    it "学生ごとの、興味を示した募集の番号の一覧を返す（興味のない学生は入らない）" do
      no_interest = create_student

      result = described_class.postings_by_student([ student.id, other_student.id, no_interest.id ])

      expect(result.keys).to contain_exactly(student.id, other_student.id)
      expect(result[student.id]).to contain_exactly(posting.id, other_posting.id)
      expect(result[other_student.id]).to eq([ posting.id ])
    end

    it "募集ごとの、興味を示した学生の番号の一覧を返す" do
      result = described_class.students_by_posting([ posting.id, other_posting.id ])

      expect(result[posting.id]).to contain_exactly(student.id, other_student.id)
      expect(result[other_posting.id]).to eq([ student.id ])
    end

    it "上限もかかる（学生ごとに1件なら、いちばん新しい募集だけ）" do
      stub_const("Recommendation::Parameters::INTERESTS_PER_STUDENT", 1)

      expect(described_class.postings_by_student([ student.id ])).to eq(student.id => [ other_posting.id ])
    end
  end
end
