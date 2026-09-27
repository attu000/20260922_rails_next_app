# work_processes（工程のマスタ）。design/designs/データベース.md の 8-5、中身はその他決め事.md の 5-8。
# 名前を processes にしないのは、Ruby 本体の Process と衝突するため（データベース.md の 8-3）。
# 共通段階（上流・中流・下流）の列と、職種の大分類との対応（並べ替えのヒント）は持たない。
# どちらも判定や計算に使わず、並び順は表示順（上流 → 下流）だけで足りるため（PR239・PR240）。
# マスタは名前で管理し、削除しない（技術構成.md の 9-1）。中身は db/seeds.rb で入れる
class CreateWorkProcesses < ActiveRecord::Migration[8.1]
  def change
    create_table :work_processes do |t|
      t.string :name, null: false
      # 「企画・設計から関われる」の対象か（企画・要件定義、設計、課題設定の3つだけ true）
      t.boolean :planning, null: false, default: false
      # 表示順（上流 → 中流 → 下流）
      t.integer :position, null: false

      t.timestamps
    end

    add_index :work_processes, :name, unique: true
  end
end
