# job_posting_work_processes（募集の工程。募集×工程の中間テーブル）。design/designs/データベース.md の 8-5。
# 募集の職種（job_posting_job_categories）と同じ形。任意で、上限なし
class CreateJobPostingWorkProcesses < ActiveRecord::Migration[8.1]
  def change
    create_table :job_posting_work_processes do |t|
      t.references :job_posting, null: false, foreign_key: true
      t.references :work_process, null: false, foreign_key: true
      # main（メインで担当）：0 ／ involved（関われる）：1（番号は JobPostingWorkProcess モデルの enum で明示する）
      t.integer :role, null: false

      t.timestamps
    end

    # UNIQUE(両方)：1つの募集に同じ工程は1回だけ。同じ工程をメインと関われるの両方には入れられない
    add_index :job_posting_work_processes, %i[job_posting_id work_process_id], unique: true
  end
end
