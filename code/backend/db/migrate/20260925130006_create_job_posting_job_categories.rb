# job_posting_job_categories（募集の職種。募集×職種の中分類の中間テーブル）。design/designs/データベース.md の 8-5。
# 主な中分類・関連する中分類とも複数、上限なし（その他決め事.md の 5-7）
class CreateJobPostingJobCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :job_posting_job_categories do |t|
      t.references :job_posting, null: false, foreign_key: true
      t.references :job_middle_category, null: false, foreign_key: true
      # main（主な中分類）：0 ／ related（関連する中分類）：1（番号は JobPostingJobCategory モデルの enum で明示する）
      t.integer :role, null: false

      t.timestamps
    end

    # UNIQUE(両方)：1つの募集に同じ中分類は1回だけ。同じ中分類を主と関連の両方には入れられない
    add_index :job_posting_job_categories, %i[job_posting_id job_middle_category_id], unique: true
  end
end
