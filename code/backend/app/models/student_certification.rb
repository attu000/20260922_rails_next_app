# 学生の資格の1行（design/designs/データベース.md の 8-5 B）。資格名を自由に入力する。
# 学生プロフィールの保存のたびに、送られた内容で消して作り直す（StudentProfile#save_profile）。
# 企業の学生検索のフリーワードの対象になる（API設計.md の 16-3 ㉒）
class StudentCertification < ApplicationRecord
  belongs_to :student_profile

  # 空白だけの資格名は、空欄（null）にそろえてから「資格名を入力してください」にする
  normalizes :name, with: ->(value) { value.presence }

  validates :name, presence: true, length: { maximum: 100 }
end
