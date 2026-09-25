# job_middle_categories（職種の中分類のマスタ）。design/designs/データベース.md の 8-5、中身はその他決め事.md の 5-7。
# どの大分類に属するかを持つ。細分類（job_minor_categories）は Phase 7 で作る
class CreateJobMiddleCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :job_middle_categories do |t|
      t.references :job_major_category, null: false, foreign_key: true
      # 例："1-1"。初期データはこの code で管理する
      t.string :code, null: false
      t.string :name, null: false
      # 学生向けの一言説明
      t.text :description, null: false
      # 表示順
      t.integer :position, null: false

      t.timestamps
    end

    add_index :job_middle_categories, :code, unique: true
  end
end
