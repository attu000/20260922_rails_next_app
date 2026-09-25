# prefectures（都道府県のマスタ）。design/designs/データベース.md の 8-5。
# id に JIS コード（北海道 1 〜 沖縄 47）をそのまま使う。db/seeds.rb で番号を指定して入れる。
# 表示順の列は持たず、id の順（北から南）に並べる
class CreatePrefectures < ActiveRecord::Migration[8.1]
  def change
    create_table :prefectures do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
