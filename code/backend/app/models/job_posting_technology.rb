# 募集の使用技術（募集×技術の中間テーブル）。design/designs/データベース.md の 8-5
class JobPostingTechnology < ApplicationRecord
  belongs_to :job_posting
  belongs_to :technology
end
