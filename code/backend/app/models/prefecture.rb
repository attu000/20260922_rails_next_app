# 都道府県のマスタ。id に JIS コード（北海道 1 〜 沖縄 47）をそのまま使う（design/designs/データベース.md の 8-5）。
# 中身は db/seeds.rb で入れる
class Prefecture < ApplicationRecord
  validates :name, presence: true

  # 表示順の列は持たず、id の順（北から南）に並べる。⑦ GET /api/options で返すときに使う
  scope :ordered, -> { order(:id) }
end
