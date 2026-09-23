# users（ログイン情報）。design/designs/データベース.md の 8-5
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # 保存前に小文字にそろえる（User モデルの normalizes）ので、重複の確認は大文字小文字を区別しない
      t.string :email, null: false
      # 暗号化したパスワード。has_secure_password が使う
      t.string :password_digest, null: false
      # 種別。student：0／company：1（番号は User モデルの enum で明示する）
      t.integer :role, null: false
      # 最終活動日。ログイン中の操作があった日の、最初の1回だけ書き込む（API設計.md の 16-1-12）
      t.date :last_active_on

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
