# 学部のマスタ。大学とは切り離した共通の一覧（design/designs/ページ設計.md の 6-6 S1）。
# 中身は db/seeds.rb で入れる（仮データ）。マスタは名前で管理し、削除しない（技術構成.md の 9-1）
class Faculty < ApplicationRecord
  # 学部 → 学科の一覧（表示順）。並べ方をここに書いておくと、まとめて読んだ（includes）ときも表示順になる
  has_many :departments, -> { order(:position) }

  validates :name, presence: true, uniqueness: true
  validates :position, presence: true

  # 表示順に並べる。⑦ GET /api/options で返すときに使う
  scope :ordered, -> { order(:position) }
end
