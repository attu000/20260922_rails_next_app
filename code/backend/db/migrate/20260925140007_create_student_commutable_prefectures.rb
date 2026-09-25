# student_commutable_prefectures（出社できる都道府県。学生×都道府県の中間テーブル）。design/designs/データベース.md の 8-5。
# 初期値なし。在住の都道府県から自動で選ばない（その他決め事.md の 5-6）
class CreateStudentCommutablePrefectures < ActiveRecord::Migration[8.1]
  def change
    create_table :student_commutable_prefectures do |t|
      t.references :student_profile, null: false, foreign_key: true
      t.references :prefecture, null: false, foreign_key: true

      t.timestamps

      # UNIQUE(両方)：同じ学生に同じ都道府県を2回付けない
      t.index %i[student_profile_id prefecture_id], unique: true
    end
  end
end
