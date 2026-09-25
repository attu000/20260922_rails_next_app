# departments（学科のマスタ）。design/designs/データベース.md の 8-5。
# 「学部 → その学部の学科」の2段階で選ぶ。どの学部にも「その他」の学科を入れる（ページ設計.md の 6-6 S1）
class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.references :faculty, null: false, foreign_key: true
      t.string :name, null: false
      # 学部の中での表示順
      t.integer :position, null: false

      t.timestamps

      # 同じ学部の中で、同じ名前の学科は1つ。「その他」は学部ごとにあるので、名前だけでは重複不可にしない
      t.index %i[faculty_id name], unique: true
    end
  end
end
