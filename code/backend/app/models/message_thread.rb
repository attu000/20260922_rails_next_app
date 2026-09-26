# スレッド（企業×学生。design/designs/データベース.md の 8-5）。
# メッセージは「募集ごと」ではなく「相手ごと」なので、企業と学生の組み合わせで1本だけ作る
class MessageThread < ApplicationRecord
  belongs_to :company_profile
  belongs_to :student_profile

  # スレッドの中のメッセージ
  has_many :messages

  # その企業とその学生のスレッドがあるか（募集詳細・企業詳細・学生詳細の has_message_thread。API設計.md の 16-3 ⑲⑳㉓）。
  # true なら、画面に「この企業とのメッセージ」「この学生とのメッセージ」のボタンを出す（ボタンは順7。PR213）。
  # スレッドはスカウトを送ったときか、応募がマッチしたときにできるので、スカウトが届いただけでも true になる。
  # 送れるかどうか（マッチ以降が1つでもあるか）とは別（権限_バリデーション.md の 17-2-3）。
  # Django の MessageThread.objects.filter(company_profile=企業, student_profile=学生).exists() にあたる
  def self.exists_between?(company_profile, student_profile)
    exists?(company_profile: company_profile, student_profile: student_profile)
  end
end
