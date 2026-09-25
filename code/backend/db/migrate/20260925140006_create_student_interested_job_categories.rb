# student_interested_job_categories（興味のある職種。学生×職種の中分類の中間テーブル）。design/designs/データベース.md の 8-5
class CreateStudentInterestedJobCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :student_interested_job_categories do |t|
      t.references :student_profile, null: false, foreign_key: true
      t.references :job_middle_category, null: false, foreign_key: true

      t.timestamps

      # UNIQUE(両方)：同じ学生に同じ職種を2回付けない
      t.index %i[student_profile_id job_middle_category_id], unique: true
    end
  end
end
