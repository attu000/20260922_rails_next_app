# プチ職業体験の自己分析（職業版の自己PR）。design/designs/データベース.md の 8-5 I、サービス概要_コンセプト.md の 12-4。
# 学生×講座に1件で、何度でも書き直せる（上書き。PR371）。企業は学生詳細で最新のものを読む。
# 自己分析を送った講座を「修了済み」と呼ぶ（PR369）
class SelfAnalysis < ApplicationRecord
  # 記述3つの長さの上限（PR391）。企業が1人の自己分析を2〜3分で読める量にするため
  TEXT_MAX_LENGTH = 400
  # 学生が送れる項目（窓口 ㊽ で受け取る項目）
  PERMITTED_ATTRIBUTES = %i[strength_hurdle_id strength_reason growth_hurdle_id growth_reason growth_detail next_step].freeze

  belongs_to :student_profile
  belongs_to :job_trial
  # 1-1 いちばん得意なハードル、2-1 いちばん伸ばしたいハードル。
  # 空欄やほかの講座のハードルの誤りは、送る項目の名前（strength_hurdle_id など）で返したいので、
  # Rails の「関連が必須」の確かめではなく、下の確かめで扱う
  belongs_to :strength_hurdle, class_name: "JobTrialHurdle", optional: true
  belongs_to :growth_hurdle, class_name: "JobTrialHurdle", optional: true

  # 2-2 伸ばしたい理由の種類。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。範囲外の値は検証エラーにする
  enum :growth_reason, {
    challenge: 0,
    curiosity: 1,
    importance: 2,
    future: 3,
    other: 4
  }, validate: { allow_nil: true }

  # 記述が空白だけで送られてきたら、空欄（null）にそろえる（必須の確かめで「入力してください」になる）
  normalizes :strength_reason, :growth_detail, :next_step, with: ->(value) { value.presence }

  validates :strength_hurdle_id, :growth_hurdle_id, :growth_reason, presence: true
  validates :strength_reason, :growth_detail, :next_step, presence: true, length: { maximum: TEXT_MAX_LENGTH }
  validate :hurdles_must_belong_to_job_trial

  # 学生のその講座の自己分析を、あれば上書き、なければ作る（Django の update_or_create に近いが、確かめてから保存する）。
  # 確かめに通らなければ保存せず、エラーを持ったまま返す。同時に2回送られて「1人×1講座に1件」に弾かれたときは、
  # データベースのエラーがそのまま上がり、窓口の共通の部品が 409 にする（API設計.md の 16-1-10）
  def self.save_for(student_profile, job_trial, attributes)
    self_analysis = find_or_initialize_by(student_profile: student_profile, job_trial: job_trial)
    self_analysis.assign_attributes(attributes.to_h.symbolize_keys.slice(*PERMITTED_ATTRIBUTES))
    self_analysis.save
    self_analysis
  end

  # 1-1 と 2-1 で同じハードルを選んだか（「得意を伸ばしたい」学生か）。保存せず、読むたびに計算する（PR360）
  def same_hurdle?
    strength_hurdle_id == growth_hurdle_id
  end

  private

  # 選んだ2つのハードルが、この講座のハードルか。ない番号も、ほかの講座のハードルも、同じ誤りにする。
  # 文言は「得意なハードルは、この講座のハードルから選んでください」の形（学科と学部の確かめと同じ形）
  def hurdles_must_belong_to_job_trial
    return if job_trial.nil?

    hurdle_ids = job_trial.hurdles.ids
    %i[strength_hurdle_id growth_hurdle_id].each do |attribute|
      value = public_send(attribute)
      errors.add(attribute, :not_in_job_trial) if value.present? && !hurdle_ids.include?(value)
    end
  end
end
