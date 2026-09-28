# 通知（design/designs/データベース.md の 8-5 E）。
# 今は企業向けの「おすすめの学生」（C10）だけ。作るのは応募・マッチのあとのジョブ（処理設計_類似度.md の 7-5）
class Notification < ApplicationRecord
  # 受け取る人
  belongs_to :user
  # 通知の対象の学生（PR323）。学生と関係ない通知もあるので、空欄を許す。
  # Rails は belongs_to の相手が空欄なら検証エラーにするので、optional で外す（Django の null=True, blank=True にあたる）
  belongs_to :student_profile, optional: true

  # 種類。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。範囲外の値は検証エラーにする
  enum :kind, { recommended_student: 0 }, validate: true

  # 未読だけ。Django の objects.filter(read_at__isnull=True) にあたる
  scope :unread, -> { where(read_at: nil) }
  # 新しい順。同じ時刻なら番号の大きい順にして、毎回同じ並びにする
  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  validates :body, presence: true
end
