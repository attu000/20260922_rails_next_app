# job_major_categories（職種の大分類のマスタ）。design/designs/データベース.md の 8-5、中身はその他決め事.md の 5-7。
# マスタは code で管理し、削除しない（技術構成.md の 9-1）。中身は db/seeds.rb で入れる
class CreateJobMajorCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :job_major_categories do |t|
      # 例："1"。初期データはこの code で管理する
      t.string :code, null: false
      t.string :name, null: false
      # 学生向けの説明
      t.text :description, null: false
      # 表示順
      t.integer :position, null: false

      t.timestamps
    end

    add_index :job_major_categories, :code, unique: true
  end
end
