# student_profiles（学生プロフィール）の残りの列。design/designs/データベース.md の 8-5。
# 順3 で作る項目（【コア】）の列だけを足す（未決内容.md の 11-2）。性格の5つの列は順9（【強み】）で足す。
# 必須は名前と活動状況だけ（その他決め事.md の 5-9）。活動状況の必須はアプリで確かめるので、データベースは NULL 可
class AddProfileDetailsToStudentProfiles < ActiveRecord::Migration[8.1]
  def change
    # 大学。一覧にない大学（海外の大学など）は university_other_name に文章で持つ
    add_reference :student_profiles, :university, foreign_key: true
    add_column :student_profiles, :university_other_name, :string
    # 学部・学科。学科が選んだ学部に属するかは、アプリで確かめる
    add_reference :student_profiles, :faculty, foreign_key: true
    add_reference :student_profiles, :department, foreign_key: true
    # 学年。undergrad_1：0 〜 other：9（番号は StudentProfile モデルの enum で明示する）
    add_column :student_profiles, :grade, :integer
    # 在住の都道府県
    add_reference :student_profiles, :prefecture, foreign_key: true

    # 自己PR（3つの問い）
    # 強み・向いていること
    add_column :student_profiles, :self_pr_strength, :text
    # 向いていないこと
    add_column :student_profiles, :self_pr_weakness, :text
    # この先やりたいこと、挑戦したいこと
    add_column :student_profiles, :self_pr_future, :text

    # 卒業年度（例：2028）。範囲の制限はなし（権限_バリデーション.md の 17-3-4）
    add_column :student_profiles, :graduation_year, :integer
    # 活動状況。not_looking：0 ／ skill_up：1 ／ job_hunting：2（番号は StudentProfile モデルの enum で明示する）
    add_column :student_profiles, :activity_status, :integer

    # 稼働条件（すべて任意。選択肢はその他決め事.md の 5-6）。limit: 2 で smallint になる
    # 週○日まで
    add_column :student_profiles, :work_days_per_week, :integer, limit: 2
    # 1日○時間まで
    add_column :student_profiles, :work_hours_per_day, :integer, limit: 2
    # ○ヶ月以上続けられる
    add_column :student_profiles, :duration_months, :integer, limit: 2
    # ○年○月から可能（月の1日の日付）。範囲の制限はなし
    add_column :student_profiles, :available_from, :date
    # 勤務形態の可否。初期状態は3つとも「可能」（多くの学生がどれも可能なため）
    add_column :student_profiles, :can_full_remote, :boolean, null: false, default: true
    add_column :student_profiles, :can_partial_remote, :boolean, null: false, default: true
    add_column :student_profiles, :can_onsite, :boolean, null: false, default: true
    # 稼働条件の備考
    add_column :student_profiles, :work_note, :text

    # 一覧の大学と「その他」の文章は、両方同時には入らない（どちらか一方か、どちらも空）
    add_check_constraint :student_profiles, "university_id IS NULL OR university_other_name IS NULL",
                         name: "student_profiles_university_or_other_name"
  end
end
