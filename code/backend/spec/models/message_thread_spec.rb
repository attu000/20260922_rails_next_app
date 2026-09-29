require "rails_helper"

# スレッドのテスト。送れるかの判定（権限_バリデーション.md の 17-2-3）、メッセージの送信（API設計.md の 16-3 ㊳㊶）、
# スレッド一覧の並び順（16-3 ㊱㊴。PR221）を確かめる
RSpec.describe MessageThread, type: :model do
  let(:thread) { create(:message_thread) }
  let(:company) { thread.company_profile }
  let(:student) { thread.student_profile }
  # この企業の掲載中の募集
  let(:job_posting) { create(:job_posting, :published, company_profile: company) }

  describe "送れるか（can_send?）" do
    it "やりとりがなければ false" do
      expect(thread.can_send?).to be(false)
    end

    it "スカウトしただけ（未マッチ）や、見送りなら false" do
      create(:candidacy, :scout, job_posting: job_posting, student_profile: student)
      create(:candidacy, job_posting: create(:job_posting, :published, company_profile: company),
                         student_profile: student, status: :declined)

      expect(thread.can_send?).to be(false)
    end

    %i[matched passed failed].each do |status|
      it "やりとりが #{status} なら true" do
        create(:candidacy, job_posting: job_posting, student_profile: student, status: status)

        expect(thread.can_send?).to be(true)
      end
    end

    it "募集が終了していても、マッチしていれば true（募集の状態は見ない）" do
      closed = create(:job_posting, :closed, company_profile: company)
      create(:candidacy, job_posting: closed, student_profile: student, status: :matched)

      expect(thread.can_send?).to be(true)
    end

    it "同じ学生の、他社の募集でのマッチは数えない" do
      create(:candidacy, job_posting: create(:job_posting, :published), student_profile: student, status: :matched)

      expect(thread.can_send?).to be(false)
    end
  end

  describe "送信（post_message）" do
    context "マッチしている" do
      before { create(:candidacy, job_posting: job_posting, student_profile: student, status: :matched) }

      it "メッセージができ、スレッドの last_message_at がそのメッセージの日時になる" do
        message = thread.post_message(student.user, "よろしくお願いします")

        expect(message).to be_persisted
        expect(message).to have_attributes(sender_user: student.user, body: "よろしくお願いします")
        expect(thread.reload.last_message_at).to eq(message.created_at)
      end

      it "本文が空なら保存せず、誤り入りのメッセージを返す。last_message_at は変わらない" do
        message = thread.post_message(company.user, "")

        expect(message).not_to be_persisted
        expect(message.errors.full_messages).to include("本文を入力してください")
        expect(thread.messages.count).to eq(0)
        expect(thread.reload.last_message_at).to be_nil
      end
    end

    it "送れない（マッチしていない）なら ConflictError。何も保存しない" do
      create(:candidacy, :scout, job_posting: job_posting, student_profile: student)

      expect { thread.post_message(company.user, "よろしくお願いします") }.to raise_error(ConflictError)
      expect(thread.messages.count).to eq(0)
    end
  end

  describe "今マッチできるスカウト（matchable_scouts。PR222・PR223）" do
    it "スカウトの未マッチ・見送りで、掲載中の募集のものが、募集ごとにすべて古い順に入る" do
      first = create(:candidacy, :scout, job_posting: job_posting, student_profile: student)
      declined = create(:candidacy, :scout, job_posting: create(:job_posting, :published, company_profile: company),
                                            student_profile: student, status: :declined)
      first.update_columns(created_at: 1.day.ago)

      expect(thread.matchable_scouts).to eq([ first, declined ])
    end

    it "募集が終了したスカウト、マッチ済みのスカウト、応募から始まったやりとりは入らない" do
      create(:candidacy, :scout, job_posting: create(:job_posting, :closed, company_profile: company), student_profile: student)
      create(:candidacy, :scout, job_posting: job_posting, student_profile: student, status: :matched)
      create(:candidacy, job_posting: create(:job_posting, :published, company_profile: company), student_profile: student)

      expect(thread.matchable_scouts).to eq([])
    end

    it "同じ学生への他社のスカウトや、同じ企業からほかの学生へのスカウトは入らない" do
      create(:candidacy, :scout, job_posting: create(:job_posting, :published), student_profile: student)
      create(:candidacy, :scout, job_posting: job_posting)

      expect(thread.matchable_scouts).to eq([])
    end
  end

  describe "企業の返事を待っている学生（awaiting_reply_student_ids。候補者一覧の未返信）" do
    # 同じ企業の、もう1人の学生とのスレッド
    let(:other_thread) { create(:message_thread, company_profile: company) }

    it "最後のメッセージを学生が送ったスレッドの学生だけが入る" do
      create(:message, message_thread: thread, sender_user: company.user, created_at: 2.hours.ago)
      create(:message, message_thread: thread, sender_user: student.user, created_at: 1.hour.ago)
      # こちらは学生が送ったあと、企業が返した
      create(:message, message_thread: other_thread, sender_user: other_thread.student_profile.user, created_at: 2.hours.ago)
      create(:message, message_thread: other_thread, sender_user: company.user, created_at: 1.hour.ago)

      ids = described_class.awaiting_reply_student_ids(company, [ student.id, other_thread.student_profile_id ])

      expect(ids).to eq(Set[student.id])
    end

    it "同じ日時なら、番号の大きい（あとに作った）メッセージを最後とみなす" do
      sent_at = 1.hour.ago
      create(:message, message_thread: thread, sender_user: company.user, created_at: sent_at)
      create(:message, message_thread: thread, sender_user: student.user, created_at: sent_at)

      expect(described_class.awaiting_reply_student_ids(company, [ student.id ])).to eq(Set[student.id])
    end

    it "メッセージがまだないスレッドは入らない" do
      thread

      expect(described_class.awaiting_reply_student_ids(company, [ student.id ])).to eq(Set[])
    end

    it "渡していない学生と、他社とのスレッドは入らない" do
      create(:message, message_thread: other_thread, sender_user: other_thread.student_profile.user)
      # 同じ学生と、他社とのスレッド。学生が最後に送っている
      others = create(:message_thread, student_profile: student)
      create(:message, message_thread: others, sender_user: student.user)

      expect(described_class.awaiting_reply_student_ids(company, [ student.id ])).to eq(Set[])
    end
  end

  describe "マッチしている募集（matched_job_postings）" do
    it "この学生とのやりとりがマッチ・合格・不合格の募集が、マッチした日の古い順に入る" do
      postings = Array.new(3) { create(:job_posting, :published, company_profile: company) }
      create(:candidacy, job_posting: postings[0], student_profile: student, status: :failed, matched_at: 1.day.ago)
      create(:candidacy, job_posting: postings[1], student_profile: student, status: :matched, matched_at: 3.days.ago)
      create(:candidacy, job_posting: postings[2], student_profile: student, status: :passed, matched_at: 2.days.ago)

      expect(thread.matched_job_postings).to eq([ postings[1], postings[2], postings[0] ])
    end

    it "未マッチ・見送りのやりとり、他社の募集、ほかの学生とのマッチは入らない" do
      create(:candidacy, :scout, job_posting: job_posting, student_profile: student)
      create(:candidacy, job_posting: create(:job_posting, :published, company_profile: company),
                         student_profile: student, status: :declined)
      create(:candidacy, job_posting: create(:job_posting, :published), student_profile: student, status: :matched)
      create(:candidacy, job_posting: create(:job_posting, :published, company_profile: company), status: :matched)

      expect(thread.matched_job_postings).to eq([])
    end
  end

  describe "並び順（recent_first）" do
    it "最後のメッセージの新しい順。メッセージがないスレッドは作った日時で比べ、先頭に居座らない" do
      old_message = create(:message_thread, last_message_at: 3.days.ago)
      new_message = create(:message_thread, last_message_at: 1.hour.ago)
      # 応募のマッチでできただけのスレッド（メッセージなし）。2日前に作った
      no_message = create(:message_thread, last_message_at: nil)
      no_message.update_columns(created_at: 2.days.ago)

      expect(described_class.recent_first).to eq([ new_message, no_message, old_message ])
    end
  end
end
