# business_types（事業形態のマスタ）。design/designs/データベース.md の 8-5、中身はその他決め事.md の 5-8。
# 名前を business_models にしないのは、クラス名 BusinessModel が Rails の「モデル」と紛らわしいため（データベース.md の 8-3）。
# マスタは名前で管理し、削除しない（技術構成.md の 9-1）。中身は db/seeds.rb で入れる
class CreateBusinessTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :business_types do |t|
      t.string :name, null: false
      # 表示順
      t.integer :position, null: false

      t.timestamps
    end

    add_index :business_types, :name, unique: true
  end
end
