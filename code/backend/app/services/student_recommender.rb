# 企業の募集にとっての、学生ごとのおすすめの点数 f(募集, 学生)（design/designs/処理設計_類似度.md の 7-2）。
# 推薦の計算は、画面や API から切り離したこの部品にまとめる（技術構成.md の 9-4）。募集検索の JobPostingRecommender と同じ形。
#
# 【仮】順13（おすすめ順）で、本物の計算に差し替える（PR214）。
# 今は全員0点。同点は最終活動の新しい順に並ぶので、並びは「最終活動が新しい順」と同じになる
class StudentRecommender
  # job_posting：点数の基準にする募集。students：点数を付ける学生の一覧。
  # 返すもの：{ 学生の番号 => 点数 }。この形は、本物の計算になっても変えない
  def self.scores(_job_posting, students)
    students.to_h { |student| [ student.id, 0.0 ] }
  end
end
