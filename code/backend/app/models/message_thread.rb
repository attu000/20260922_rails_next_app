# スレッド（企業×学生。design/designs/データベース.md の 8-5）。
# メッセージは「募集ごと」ではなく「相手ごと」なので、企業と学生の組み合わせで1本だけ作る
class MessageThread < ApplicationRecord
  belongs_to :company_profile
  belongs_to :student_profile

  # スレッドの中のメッセージ
  has_many :messages
end
