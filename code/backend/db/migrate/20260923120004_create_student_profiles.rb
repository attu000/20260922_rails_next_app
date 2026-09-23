# student_profiles（学生プロフィール）。design/designs/データベース.md の 8-5
# Phase 5 では user_id と氏名だけを作る。残りの列は、学生プロフィールの機能を作るときに Phase 6 で足す（未決内容.md の 11-2）
class CreateStudentProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :student_profiles do |t|
      # UNIQUE：1人1アカウント
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      # 氏名
      t.string :name, null: false

      t.timestamps
    end
  end
end
