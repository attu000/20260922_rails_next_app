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
