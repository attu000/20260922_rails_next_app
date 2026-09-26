# 応募理由・マッチ理由（design/designs/データベース.md の 8-5 candidacy_reasons）。
# 理由の1つは、比較で1つのまとまりとして見せる項目の1つに対応する（その他決め事.md の 5-1）
class CandidacyReason < ApplicationRecord
  belongs_to :candidacy

  # 並びは画面に出す順（関係の近いものを隣に置く）。番号は「新しい値は末尾に足す」決まり（技術構成.md の 9-1）で、並び順とは別。
  # 番号は reason_mask のビットの位置にもなるので、あとから変えない
  enum :reason, {
    business: 0,
    industry: 1,
    job_major_category: 11,
    job_middle_category: 2,
    business_type: 9,
    work_process: 3,
    internship_details: 4,
    growth: 10,
    culture: 5,
    hourly_wage: 6,
    work_conditions: 7,
    technologies: 8
  }, validate: true

  # 理由の組を、1つの数（reason_mask）にする。理由の番号 i ごとに「2 の i 乗」を足し合わせる。
  # 例：事業内容（0）とカルチャー（5）なら 1 + 32 = 33。12個すべてなら 4095
  def self.mask_for(reasons)
    reasons.sum { |reason| 1 << self.reasons.fetch(reason.to_s) }
  end
end
