# 募集の工程（募集×工程の中間テーブル）。design/designs/データベース.md の 8-5。
# 募集の職種（JobPostingJobCategory）と同じ形。同じ工程をメインと関われるの両方には入れられない（データベースの UNIQUE でも守る）
class JobPostingWorkProcess < ApplicationRecord
  belongs_to :job_posting
  belongs_to :work_process

  # メインで担当する工程か、関われる工程か。番号を明示する（技術構成.md の 9-1）
  enum :role, {
    main: 0,
    involved: 1
  }
end
