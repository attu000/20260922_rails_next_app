# テスト用のメッセージを作るひな形。create(:message) で「企業が学生に送ったメッセージ」になる。
# スレッドも一緒に作る（スレッドは企業×学生で1本）
FactoryBot.define do
  factory :message do
    message_thread do
      MessageThread.create!(
        company_profile: create(:company_user).company_profile,
        student_profile: create(:student_user).student_profile
      )
    end
    # 送った人は、スレッドの企業のアカウント
    sender_user { message_thread.company_profile.user }
    body { "はじめまして。募集を見ていただけないでしょうか。" }
  end
end
