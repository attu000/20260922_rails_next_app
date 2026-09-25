# 学生の出社できる都道府県（学生×都道府県の中間テーブル）。design/designs/データベース.md の 8-5
class StudentCommutablePrefecture < ApplicationRecord
  belongs_to :student_profile
  belongs_to :prefecture
end
