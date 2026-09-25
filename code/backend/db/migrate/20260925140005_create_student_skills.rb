# student_skills（プログラミング歴）。design/designs/データベース.md の 8-5。
# 保存のたびに、送られた内容で消して作り直す（API設計.md の 16-3 ⑯）
#
# 目印（インデックス）と CHECK は create_table の中に書く。取り消し（db:rollback）のときに、テーブルと一緒に消えるようにするため
class CreateStudentSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :student_skills do |t|
      t.references :student_profile, null: false, foreign_key: true
      # マスタから選んだ技術
      t.references :technology, foreign_key: true
      # マスタにない技術（「その他」）の名前
      t.string :other_name
      # 年数。0.5年なども入る（最大 99.9。入力の上限 50 はモデルの検証で確かめる）
      t.decimal :years, precision: 3, scale: 1
      # レベル。v1：0 ／ v2：1 ／ v3：2 ／ v4：3（番号は StudentSkill モデルの enum で明示する）
      t.integer :level, null: false

      t.timestamps

      # 同じ学生で同じ技術は1行だけ。「その他」の行は technology_id が NULL で、NULL どうしは重複と見なされないので、何行でも作れる
      t.index %i[student_profile_id technology_id], unique: true
      # 技術か「その他」の名前の、どちらか一方だけが入る
      t.check_constraint "(technology_id IS NULL) <> (other_name IS NULL)",
                         name: "student_skills_technology_or_other_name"
    end
  end
end
