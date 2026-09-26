# 学生にとっての、募集ごとのおすすめの点数 f(募集, 学生)（design/designs/処理設計_類似度.md の 7-2）。
# 推薦の計算は、画面や API から切り離したこの部品にまとめる（技術構成.md の 9-4）。
#
# 【仮】順13（おすすめ順）で、本物の計算に差し替える。
# 今は全件0点。同点は新着順に並ぶので、並びは新着順と同じになる。
# ランダムな点数にすると、ページを開くたびに並びが変わり、ページをまたいで同じ募集が出たり抜けたりするため
class JobPostingRecommender
  # student：点数を付けてもらう学生。job_postings：点数を付ける募集の一覧。
  # 返すもの：{ 募集の番号 => 点数 }。この形は、本物の計算になっても変えない
  def self.scores(student, job_postings)
    job_postings.to_h { |job_posting| [ job_posting.id, 0.0 ] }
  end
end
