# 学生プロフィールの【仕上げ】の付属テーブル3つ（design/designs/データベース.md の 8-5 B）。順17。
# - student_links（外部リンク）：URL と表示名。保存のたびに消して作り直す（プログラミング歴と同じ）
# - student_certifications（資格）：資格名。同上
# - student_job_hunting_prefectures（就活希望エリア）：学生×都道府県の中間テーブル（出社できる都道府県と同じ形）
# 外部キーは既定の動き（参照されている行は消せない）のまま。誤ってデータが消えないようにするため（技術構成.md の 9-5）
class CreateStudentLinksCertificationsAndJobHuntingPrefectures < ActiveRecord::Migration[8.1]
  def change
    create_table :student_links do |t|
      t.references :student_profile, null: false, foreign_key: true
      # URL の形（http:// か https:// で始まるか）は、アプリで確かめる（StudentLink）
      t.string :url, null: false
      # 「GitHub」「ポートフォリオ」などの表示名。任意
      t.string :title

      t.timestamps
    end

    create_table :student_certifications do |t|
      t.references :student_profile, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    create_table :student_job_hunting_prefectures do |t|
      t.references :student_profile, null: false, foreign_key: true
      t.references :prefecture, null: false, foreign_key: true

      t.timestamps

      # UNIQUE(両方)：同じ学生に同じ都道府県を2回付けない
      t.index %i[student_profile_id prefecture_id], unique: true
    end
  end
end
