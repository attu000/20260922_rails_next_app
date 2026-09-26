# テスト用のスレッドとメッセージを作るひな形。
# create(:message_thread) で「企業と学生を1組作り、その2人のスレッド」になる（スレッドは企業×学生で1本）。
# create(:message) で「企業が学生に送ったメッセージ」になる。スレッドも一緒に作る
FactoryBot.define do
  factory :message_thread do
    company_profile { create(:company_user).company_profile }
    student_profile { create(:student_user).student_profile }
  end

  factory :message do
    message_thread
    # 送った人は、スレッドの企業のアカウント
    sender_user { message_thread.company_profile.user }
    body { "はじめまして。募集を見ていただけないでしょうか。" }
  end
end
