# プログラミング歴の1行（design/designs/データベース.md の 8-5）。
# 技術はマスタから選び、なければ「その他」に名前を書く。どちらか一方だけが入る（データベースの CHECK でも守る）。
# 学生プロフィールの保存のたびに、送られた内容で消して作り直す（StudentProfile#save_profile）
class StudentSkill < ApplicationRecord
  include MasterIdsValidation

  # 年数の上限（権限_バリデーション.md の 17-3-4）
  YEARS_MAX = 50

  belongs_to :student_profile
  # 「その他」の行は空
  belongs_to :technology, optional: true

  # レベル（自己申告。その他決め事.md の 5-3）。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。
  # 範囲外の値は検証エラーにする。空欄は下の presence で「レベルを入力してください」にする
  enum :level, {
    v1: 0,
    v2: 1,
    v3: 2,
    v4: 3
  }, validate: { allow_nil: true }

  # 「その他」の名前が空白だけなら、空欄（null）にそろえる。空白だけの名前で CHECK をすり抜けないようにするため
  normalizes :other_name, with: ->(value) { value.presence }

  validates :level, presence: true
  validates :other_name, length: { maximum: 100 }
  # 年数は任意。入っていれば 0〜50 の、0.5刻みの数
  validates :years, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: YEARS_MAX }, allow_nil: true
  validate :years_must_be_half_step
  validate :technology_or_other_name_must_be_one
  validate { validate_master_id(:technology_id, technology_id, Technology) }

  private

  # 0.5刻みか。データベースに入れる前の、送られたままの値で確かめる
  # （小数点以下1桁の列に入れると 1.04 が 1.0 に丸められ、誤りに気づけないため）
  def years_must_be_half_step
    raw = years_before_type_cast
    return if raw.blank?

    value = BigDecimal(raw.to_s, exception: false)
    # 数値でないときは、上の numericality が「年数は数値で入力してください」を出す
    return if value.nil?

    errors.add(:years, :half_step) unless (value * 2).frac.zero?
  end

  # 技術か「その他」の名前の、どちらか一方だけ
  def technology_or_other_name_must_be_one
    if technology_id.blank? && other_name.blank?
      errors.add(:technology_id, :blank)
    elsif technology_id.present? && other_name.present?
      errors.add(:other_name, :present)
    end
  end
end
