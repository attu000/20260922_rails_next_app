# 大学のマスタ。中身は db/seeds.rb で入れる（design/designs/データベース.md の 8-5。デモ用に20校ほどの仮置き）。
# マスタは文部科学省の学校コードで管理し、削除しない（技術構成.md の 9-1）
class University < ApplicationRecord
  validates :school_code, presence: true, uniqueness: true
  validates :name, presence: true

  # 表示順の列は持たないので、学校コードの順に並べる。⑦ GET /api/options で返すときに使う。
  # 学校コードは「F1＋都道府県番号＋設置区分（1国・2公・3私）…」の形なので、北から南へ、同じ都道府県の中では国立→公立→私立の順になる
  scope :ordered, -> { order(:school_code) }
end
