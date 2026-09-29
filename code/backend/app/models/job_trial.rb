# プチ職業体験の講座（design/designs/データベース.md の 8-5 I、サービス概要_コンセプト.md の 12章）。
# 中身は db/job_trials/ の YAML に書き、db/seeds.rb の流れで読み込む（JobTrialLoader。PR376）。
# 画面からは読むだけ。削除しない（PR383）
class JobTrial < ApplicationRecord
  belongs_to :job_middle_category
  # ハードルは講座の中の順番で並べる
  has_many :hurdles, -> { order(:position) }, class_name: "JobTrialHurdle"
  has_many :job_trial_work_processes
  # 工程は工程の表示順で並べる。まとめて読んだ（includes）ときもこの順になるので、work_process_ids も表示順になる
  has_many :work_processes, -> { order(:position) }, through: :job_trial_work_processes
  has_many :self_analyses

  validates :code, presence: true, uniqueness: true
  validates :title, :intro, :position, presence: true

  # 一覧の並び順
  scope :ordered, -> { order(:position) }
end
