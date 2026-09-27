# 学生の興味のある業界（学生×業界の中間テーブル）。design/designs/データベース.md の 8-5
class StudentInterestedIndustry < ApplicationRecord
  belongs_to :student_profile
  belongs_to :industry
end
