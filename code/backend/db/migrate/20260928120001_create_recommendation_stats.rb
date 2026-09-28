# student_recommendation_stats・job_posting_recommendation_stats（推薦の集計。学生・募集ごとに1行）。
# design/designs/データベース.md の 8-5 F、処理設計_類似度.md の 7-5。【強み】の順12。
# 件数（interest_count）と self_weight は応募・マッチのあとのジョブで、項目数（〜_count）はプロフィール・募集の保存と
# 同じトランザクションで数え直す。どれも元データから数え直して上書きするので、行の中身はいつ作り直してもよい
class CreateRecommendationStats < ActiveRecord::Migration[8.1]
  def change
    create_table :student_recommendation_stats do |t|
      # 1人1行。references が作る普通の索引の代わりに、UNIQUE の索引にする（upsert もこの索引で行を見分ける）
      t.references :student_profile, null: false, foreign_key: true, index: { unique: true }
      # 興味を示した募集の数 |A(S)|
      t.integer :interest_count, null: false, default: 0
      # 自分自身との共起の値 W(S)。float は PostgreSQL の double precision になる
      t.float :self_weight, null: false, default: 0
      # Content のジャカード係数の分母に使う項目数（PR286）
      t.integer :job_middle_category_count, null: false, default: 0
      t.integer :job_major_category_count, null: false, default: 0
      t.integer :technology_count, null: false, default: 0
      t.integer :industry_count, null: false, default: 0

      t.timestamps
    end

    create_table :job_posting_recommendation_stats do |t|
      # 1募集1行
      t.references :job_posting, null: false, foreign_key: true, index: { unique: true }
      # 興味を示した学生の数 |B(P)|
      t.integer :interest_count, null: false, default: 0
      # 自分自身との共起の値 W(P)
      t.float :self_weight, null: false, default: 0
      # 項目数。工程は募集どうしの比較にだけ使うので、募集の側にだけある
      t.integer :job_middle_category_count, null: false, default: 0
      t.integer :job_major_category_count, null: false, default: 0
      t.integer :work_process_count, null: false, default: 0
      t.integer :technology_count, null: false, default: 0
      t.integer :industry_count, null: false, default: 0

      t.timestamps
    end
  end
end
