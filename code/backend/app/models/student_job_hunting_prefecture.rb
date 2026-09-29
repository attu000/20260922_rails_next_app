# 学生の就活希望エリア（学生×都道府県の中間テーブル）。design/designs/データベース.md の 8-5。
# 検索やおすすめには使わず、学生詳細に表示するだけ
class StudentJobHuntingPrefecture < ApplicationRecord
  belongs_to :student_profile
  belongs_to :prefecture
end
