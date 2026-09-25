# industries（業界（事業分野）のマスタ）。design/designs/データベース.md の 8-5、中身はその他決め事.md の 5-8。
# マスタは名前で管理し、削除しない（技術構成.md の 9-1）。中身は db/seeds.rb で入れる
class CreateIndustries < ActiveRecord::Migration[8.1]
  def change
    create_table :industries do |t|
      t.string :name, null: false
      # 表示順
      t.integer :position, null: false

      t.timestamps
    end

    add_index :industries, :name, unique: true
  end
end
