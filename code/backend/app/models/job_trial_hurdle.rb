# プチ職業体験の講座のハードル（解説と問題）。design/designs/データベース.md の 8-5 I。
# 問題は1ハードルに1問で、選択肢は choices（jsonb。Django の JSONField）に持つ（PR380）。
# 正否の判定はここに置き、何も記録しない（PR355・PR377）
class JobTrialHurdle < ApplicationRecord
  # 選択肢1つが持つ項目
  CHOICE_KEYS = %w[key body correct explanation].freeze

  belongs_to :job_trial

  # 選択肢の項目名を文字にそろえる。データベースから読んだ値は文字の項目名なので、保存前（記号の項目名で入れたとき）も同じ形で扱えるように
  normalizes :choices, with: ->(rows) { rows.is_a?(Array) ? rows.map { |row| row.is_a?(Hash) ? row.deep_stringify_keys : row } : rows }

  validates :code, presence: true, uniqueness: { scope: :job_trial_id }
  validates :position, :name, :overview, :difficulty, :tips, :example, :goal, :question, presence: true
  validate :choices_must_be_well_formed

  # 選んだ選択肢（key）の正否と解説を返す。その問題にない key なら nil（窓口が 422 にする）。
  # 間違えたときも、正解の選択肢は返さない（正解するまで選び直す形のため。API設計.md の 16-3 ㊼）
  def check(choice_key)
    choice = choices.find { |row| row["key"] == choice_key.to_s }
    return nil if choice.nil?

    { correct: choice["correct"], explanation: choice["explanation"] }
  end

  private

  # YAML の書き間違いを、読み込みの時点で止めるための確かめ（画面から入力するものではない）。
  # 選択肢は配列で、1つずつ key・body・correct・explanation を持ち、key が重複せず、正解がちょうど1つ
  def choices_must_be_well_formed
    rows = choices
    unless rows.is_a?(Array) && rows.present? && rows.all? { |row| well_formed_choice?(row) }
      errors.add(:choices, :invalid)
      return
    end

    errors.add(:choices, :duplicated) if rows.map { |row| row["key"] }.uniq.size != rows.size
    errors.add(:choices, :invalid) if rows.count { |row| row["correct"] == true } != 1
  end

  def well_formed_choice?(row)
    row.is_a?(Hash) &&
      row.keys.sort == CHOICE_KEYS.sort &&
      row.values_at("key", "body", "explanation").all? { |value| value.is_a?(String) && value.present? } &&
      [ true, false ].include?(row["correct"])
  end
end
