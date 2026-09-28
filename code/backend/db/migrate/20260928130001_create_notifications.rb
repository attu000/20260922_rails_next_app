# notifications（通知）。design/designs/データベース.md の 8-5 E。【強み】の順15。
# 種類に関係なく使える汎用の形。今は企業向けの「おすすめの学生」だけで、応募・マッチのあとのジョブが作る（処理設計_類似度.md の 7-5）
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      # 受け取る人。「受け取る人で探す」だけの目印は作らない。下の (user_id, created_at) の目印が、先頭の列で同じ役目を果たすため
      t.references :user, null: false, foreign_key: true, index: false
      # 通知の対象の学生（PR323）。学生と関係ない通知（運営からのお知らせなど）は空欄。
      # 普通の目印を残す。「この学生の通知を、もうどの会社に送ったか」を探すため（PR322）
      t.references :student_profile, null: true, foreign_key: true
      # 種類。recommended_student：0。今後の種類は末尾の番号で足す
      t.integer :kind, null: false
      # 本文。作ったときの文言で固定する
      t.text :body, null: false
      # 押したときの移動先（アプリ内のパス）。空欄なら押しても移動しない
      t.string :link_path
      # 既読にした日時。空欄＝未読
      t.datetime :read_at

      t.timestamps

      # 通知の画面で、自社宛てを新しい順に出すため
      t.index %i[user_id created_at]
      # ヘッダーの未読件数を数えるため
      t.index %i[user_id read_at]
    end
  end
end
