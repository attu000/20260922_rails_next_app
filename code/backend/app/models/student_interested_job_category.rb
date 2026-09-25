# 学生の興味のある職種（学生×職種の中分類の中間テーブル）。design/designs/データベース.md の 8-5
class StudentInterestedJobCategory < ApplicationRecord
  belongs_to :student_profile
  belongs_to :job_middle_category
end
