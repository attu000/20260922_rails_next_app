# job_posting_job_trials（募集に近い講座。募集×プチ職業体験の講座の中間テーブル）。design/designs/データベース.md の 8-5 I。
# 企業が募集詳細編集で選び、学生の募集詳細の枠に出す（PR374）。任意、複数。
# 外部キーは CASCADE にしない（技術構成.md の 9-1）。仮のデータの入れ直しでは、募集を消す前にこの表も消す
class CreateJobPostingJobTrials < ActiveRecord::Migration[8.1]
  def change
    create_table :job_posting_job_trials do |t|
      t.references :job_posting, null: false, foreign_key: true
      t.references :job_trial, null: false, foreign_key: true

      t.timestamps
    end

    # UNIQUE(両方)：同じ募集に同じ講座を2回付けない
    add_index :job_posting_job_trials, %i[job_posting_id job_trial_id], unique: true
  end
end
