# job_posting_business_types（募集の事業形態。募集×事業形態の中間テーブル）。design/designs/データベース.md の 8-5。
# 任意で、上限なし。企業プロフィールの事業形態（company_business_types）とは別に持ち、空欄でも企業の値で補わない。
# 検索・おすすめ・比較にはこの値を使う（その他決め事.md の 5-8）
class CreateJobPostingBusinessTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :job_posting_business_types do |t|
      t.references :job_posting, null: false, foreign_key: true
      t.references :business_type, null: false, foreign_key: true

      t.timestamps
    end

    # UNIQUE(両方)：同じ募集に同じ事業形態を2回付けない
    add_index :job_posting_business_types, %i[job_posting_id business_type_id], unique: true
  end
end
