# ログイン情報。企業・学生の両方がこのモデルでログインし、プロフィールは種別ごとに別のテーブルで持つ。
# Rails 8 の認証ジェネレーターのひな形と同じ形で書いている（design/designs/技術構成.md の 3-1）
class User < ApplicationRecord
  # パスワードの暗号化と照合。Django の set_password / check_password にあたる。
  # 72バイトを超えるパスワードは、ここで検証エラーになる（権限_バリデーション.md の 17-3-4）
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_one :company_profile
  has_one :student_profile

  # 種別。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。範囲外の値は検証エラーにする
  enum :role, { student: 0, company: 1 }, validate: true

  # 前後の空白を除き、小文字にそろえてから保存・検索する（データベース.md の 8-5）
  normalizes :email, with: ->(email) { email.strip.downcase }

  # 形式と長さの決まり（権限_バリデーション.md の 17-3-4）
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
end
