# やりとり（募集×学生。design/designs/データベース.md の 8-5）。
# 応募・スカウトのどちらから始まっても同じ「やりとり」になる。状態の移り変わりは権限_バリデーション.md の 17-2-1 が正
class Candidacy < ApplicationRecord
  belongs_to :job_posting
  belongs_to :student_profile

  # 応募理由・マッチ理由
  has_many :candidacy_reasons

  # 発生元と状態。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。
  # 状態は、【コア】で使わない見送り・合格・不合格も含めて、5つを最初から書く（技術構成.md の 9-1-1 の3）
  enum :origin, {
    application: 0,
    scout: 1
  }, validate: true
  enum :status, {
    unmatched: 0,
    matched: 1,
    declined: 2,
    passed: 3,
    failed: 4
  }, validate: true

  # 企業から見た、やりとりの状態のタグ（API設計.md の 16-3 ㉑・形D）。
  # 「未対応応募」は発生元と状態の組み合わせに付けた名前なので、画面側では組み立てず、ここで計算して返す（16-1-9）
  def tag
    return status unless unmatched?

    application? ? "pending_application" : "scouted"
  end

  # 学生から見た状態（API設計.md の形E、データベース.md の 8-7）。
  # 見送り・合格・不合格は学生に見せないので、見送りは応募済み・スカウトありのまま、合格・不合格はマッチ済みに見せる
  def my_status
    return "matched" if matched? || passed? || failed?

    application? ? "applied" : "scouted"
  end
end
