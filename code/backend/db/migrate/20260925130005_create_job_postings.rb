# job_postings（募集）。design/designs/データベース.md の 8-5。
# 順2 で作る項目（【コア】）の列だけを作る（未決内容.md の 11-2）。
# カルチャーの5つの列は順9（【強み】）、目的・採用につながる可能性・求める人材の列は【仕上げ】で足す。
#
# 必須は2段（その他決め事.md の 5-9、権限_バリデーション.md の 17-3-3）。
# 常に必須：状態、タイトル。掲載に必要（状態が掲載中のときだけ必須）：インターンですること、時給。
# 非公開なら書きかけでも保存できる（下書きとして使う）。
#
# 目印（インデックス）と CHECK は create_table の中に書く。取り消し（db:rollback）のときに、テーブルと一緒に消えるようにするため
class CreateJobPostings < ActiveRecord::Migration[8.1]
  def change
    create_table :job_postings do |t|
      t.references :company_profile, null: false, foreign_key: true

      # 状態。unpublished（非公開）：0 ／ published（掲載中）：1 ／ closed（終了）：2（番号は JobPosting モデルの enum で明示する）
      t.integer :status, null: false, default: 0
      # 最初に掲載中にした日時。再掲載しても更新しない（権限_バリデーション.md の 17-2-2）
      t.datetime :published_at

      # 募集概要
      t.string :title, null: false
      # どんな会社か。空欄なら企業プロフィールの値を表示する
      t.text :about
      # 事業内容。同上
      t.text :business_description
      # インターンですること（掲載に必要）
      t.text :internship_details
      # 成長イメージ
      t.text :growth

      # 稼働条件（すべて任意。選択肢はその他決め事.md の 5-6）。limit: 2 で smallint になる
      # 週○日以上
      t.integer :min_work_days_per_week, limit: 2
      # 1日○時間以上
      t.integer :min_work_hours_per_day, limit: 2
      # 最低○ヶ月以上
      t.integer :min_duration_months, limit: 2
      # ○年○月から（月の1日の日付）。空欄は「随時」
      t.date :start_month
      # 勤務形態。full_remote：0 ／ partial_remote：1 ／ onsite：2（番号は JobPosting モデルの enum で明示する）
      t.integer :work_style
      # 勤務形態の補足
      t.string :work_style_note
      # 勤務地
      t.references :prefecture, foreign_key: true
      # 最寄り駅など
      t.string :work_location_note
      # 土日OK
      t.boolean :weekend_ok, null: false, default: false
      # 稼働条件の備考
      t.text :work_note

      # 時給（円。掲載に必要）
      t.integer :hourly_wage
      # 必須要件（名前に「必須」と付くが、入力は任意）
      t.text :requirements
      # 歓迎要件
      t.text :preferred_requirements
      # 使用技術の補足
      t.text :technology_note

      t.timestamps

      # 学生の募集検索で、掲載中を新着順に並べるときに使う
      t.index %i[status published_at]
      # 時給は0より大きい（空欄はこの条件の対象外）。上限（100,000円）は入力の決まりなので、モデルの検証で確かめる（権限_バリデーション.md の 17-3-4）
      t.check_constraint "hourly_wage > 0", name: "job_postings_hourly_wage_positive"
      # 掲載に必要：状態が掲載中（1）なら、インターンですることと時給は空欄不可。モデルの検証と同じ決まりを、データベースでも守る
      t.check_constraint "status <> 1 OR (internship_details IS NOT NULL AND hourly_wage IS NOT NULL)",
                         name: "job_postings_published_requires_details"
    end
  end
end
