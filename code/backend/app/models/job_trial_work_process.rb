# プチ職業体験の講座の工程のタグ（講座×工程の中間テーブル）。1講座に1つ以上（PR357）。
# YAML の読み込み（JobTrialLoader）のたびに、YAML の内容で置き換える
class JobTrialWorkProcess < ApplicationRecord
  belongs_to :job_trial
  belongs_to :work_process
end
