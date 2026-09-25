# universities（大学のマスタ）。design/designs/データベース.md の 8-5。
# マスタは学校コードで管理し、削除しない（技術構成.md の 9-1）。中身は db/seeds.rb で入れる（デモ用に20校ほどの仮置き）。
# 一覧にない大学は、student_profiles.university_other_name に文章で持つ
#
# 目印（インデックス）は create_table の中に書く。取り消し（db:rollback）のときに、テーブルと一緒に消えるようにするため
class CreateUniversities < ActiveRecord::Migration[8.1]
  def change
    create_table :universities do |t|
      # 文部科学省の学校コード
      t.string :school_code, null: false
      t.string :name, null: false

      t.timestamps

      t.index :school_code, unique: true
    end
  end
end
