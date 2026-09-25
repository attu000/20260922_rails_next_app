# 募集の職種（募集×職種の中分類の中間テーブル）。design/designs/データベース.md の 8-5。
# 同じ中分類を主と関連の両方には入れられない（その他決め事.md の 5-7。データベースの UNIQUE でも守る）
class JobPostingJobCategory < ApplicationRecord
  belongs_to :job_posting
  belongs_to :job_middle_category

  # 主な中分類か、関連する中分類か。番号を明示する（技術構成.md の 9-1）
  enum :role, {
    main: 0,
    related: 1
  }
end
