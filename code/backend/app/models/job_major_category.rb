# 職種の大分類のマスタ。中身は db/seeds.rb で入れる（design/designs/その他決め事.md の 5-7）。
# マスタは code で管理し、削除しない（技術構成.md の 9-1）
class JobMajorCategory < ApplicationRecord
  # 大分類 → 中分類の一覧（表示順）。Django の ForeignKey の related_name にあたる。
  # 並べ方をここに書いておくと、まとめて読んだ（includes）ときも表示順になる
  has_many :job_middle_categories, -> { order(:position) }

  validates :code, presence: true, uniqueness: true
  validates :name, :description, :position, presence: true

  # 表示順に並べる。⑦ GET /api/options で返すときに使う
  scope :ordered, -> { order(:position) }
end
