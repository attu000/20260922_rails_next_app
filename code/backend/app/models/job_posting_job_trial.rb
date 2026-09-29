# 募集に近いプチ職業体験の講座（募集×講座の中間テーブル）。design/designs/データベース.md の 8-5 I。
# 企業が募集詳細編集で選び、学生の募集詳細の枠に出す（PR374）
class JobPostingJobTrial < ApplicationRecord
  belongs_to :job_posting
  belongs_to :job_trial
end
