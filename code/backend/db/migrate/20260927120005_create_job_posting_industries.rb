# job_posting_industries（募集の業界。募集×業界の中間テーブル）。design/designs/データベース.md の 8-5。
# 任意で、上限なし。企業プロフィールの業界（company_industries）とは別に持ち、空欄でも企業の値で補わない。
# 検索・おすすめ・比較にはこの値を使う（その他決め事.md の 5-8）
class CreateJobPostingIndustries < ActiveRecord::Migration[8.1]
  def change
    create_table :job_posting_industries do |t|
      t.references :job_posting, null: false, foreign_key: true
      t.references :industry, null: false, foreign_key: true

      t.timestamps
    end

    # UNIQUE(両方)：同じ募集に同じ業界を2回付けない
    add_index :job_posting_industries, %i[job_posting_id industry_id], unique: true
  end
end
