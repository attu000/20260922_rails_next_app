# technologies（言語・フレームワーク・技術のマスタ。企業・学生で共通）。design/designs/データベース.md の 8-5、中身はその他決め事.md の 5-8。
# マスタは名前で管理し、削除しない（技術構成.md の 9-1）。中身は db/seeds.rb で入れる
class CreateTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :technologies do |t|
      t.string :name, null: false
      # 区分。language：0 〜 other：3（番号は Technology モデルの enum で明示する）
      t.integer :category, null: false
      # 表示順（区分ごとに、よく使われるものを上）
      t.integer :position, null: false

      t.timestamps
    end

    add_index :technologies, :name, unique: true
  end
end
