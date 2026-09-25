# faculties（学部のマスタ）。design/designs/データベース.md の 8-5。
# 大学とは切り離した共通の一覧（ページ設計.md の 6-6 S1）。中身は db/seeds.rb で入れる（仮データ）。
# マスタは名前で管理し、削除しない（技術構成.md の 9-1）
class CreateFaculties < ActiveRecord::Migration[8.1]
  def change
    create_table :faculties do |t|
      t.string :name, null: false
      # 表示順
      t.integer :position, null: false

      t.timestamps

      t.index :name, unique: true
    end
  end
end
