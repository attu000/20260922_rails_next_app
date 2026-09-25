# 職種の中分類のマスタ。中身は db/seeds.rb で入れる（design/designs/その他決め事.md の 5-7）。
# マスタは code で管理し、削除しない（技術構成.md の 9-1）
class JobMiddleCategory < ApplicationRecord
  belongs_to :job_major_category

  validates :code, presence: true, uniqueness: true
  validates :name, :description, :position, presence: true

  # 表示順に並べる（大分類の中での順）。⑦ GET /api/options で返すときに使う
  scope :ordered, -> { order(:position) }
end
