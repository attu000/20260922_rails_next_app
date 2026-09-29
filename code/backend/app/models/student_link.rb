# 学生の外部リンクの1行（design/designs/データベース.md の 8-5 B）。GitHub・ポートフォリオ・成果物など。
# 学生プロフィールの保存のたびに、送られた内容で消して作り直す（StudentProfile#save_profile）
class StudentLink < ApplicationRecord
  # URL の長さの上限（権限_バリデーション.md の 17-3-4）
  URL_MAX_LENGTH = 500
  # http:// か https:// で始まり、その後ろに空白でない文字が続く（PR338）。
  # 設計書の「http:// か https:// で始まること」に、「https:// だけ」や空白入りを弾く決まりを足した（学生詳細でリンクとして開けないため）。
  # 大文字の HTTPS:// も通す（ブラウザは同じものとして扱う）
  URL_FORMAT = %r{\Ahttps?://\S+\z}i

  belongs_to :student_profile

  # 表示名が空白だけなら、空欄（null）にそろえる
  normalizes :title, with: ->(value) { value.presence }

  validates :url, presence: true, length: { maximum: URL_MAX_LENGTH }
  # 空のときは上の presence が「URLを入力してください」を出すので、形の確かめは値があるときだけ
  validates :url, format: { with: URL_FORMAT, message: :http_url }, allow_blank: true
  validates :title, length: { maximum: 100 }
end
