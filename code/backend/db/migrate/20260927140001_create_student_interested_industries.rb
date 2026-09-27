# student_interested_industries（興味のある業界。学生×業界の中間テーブル）。design/designs/データベース.md の 8-5。
# 【仕上げ】の予定だったが、学生詳細の比較（業界）に使うので順10 で前倒しした（PR254）
class CreateStudentInterestedIndustries < ActiveRecord::Migration[8.1]
  def change
    create_table :student_interested_industries do |t|
      t.references :student_profile, null: false, foreign_key: true
      t.references :industry, null: false, foreign_key: true

      t.timestamps

      # UNIQUE(両方)：同じ学生に同じ業界を2回付けない
      t.index %i[student_profile_id industry_id], unique: true
    end
  end
end
