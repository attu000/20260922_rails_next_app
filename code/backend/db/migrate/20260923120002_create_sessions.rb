# sessions（ログイン中のセッション）。design/designs/データベース.md の 8-5
# Cookie には署名付きのセッション番号だけを入れ、中身はこのテーブルで持つ（Django の django_session と同じ考え方）
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      # ログイン元の IP アドレスと、ブラウザの情報
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
