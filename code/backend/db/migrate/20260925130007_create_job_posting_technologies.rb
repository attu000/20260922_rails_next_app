# job_posting_technologies（募集の使用技術。募集×技術の中間テーブル）。design/designs/データベース.md の 8-5。
# 必要レベルは持たない（その他決め事.md の 5-3）
class CreateJobPostingTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :job_posting_technologies do |t|
      t.references :job_posting, null: false, foreign_key: true
      t.references :technology, null: false, foreign_key: true

      t.timestamps
    end

    # UNIQUE(両方)：同じ募集に同じ技術を2回付けない
    add_index :job_posting_technologies, %i[job_posting_id technology_id], unique: true
  end
end
