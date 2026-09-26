# メッセージ（design/designs/データベース.md の 8-5）。
# 種類に関係なく共通の「純粋なメッセージ」。スカウト文なら scout_message が付く
class Message < ApplicationRecord
  belongs_to :message_thread
  # 送った人。列の名前（sender_user_id）と行き先のモデルの名前（User）が違うので、class_name で指定する。
  # Django の ForeignKey(User, related_name=...) にあたる
  belongs_to :sender_user, class_name: "User"

  # スカウト文なら、その記録
  has_one :scout_message

  # 形式と長さの決まり（権限_バリデーション.md の 17-3-4）。スカウト文もメッセージも同じ
  validates :body, presence: true, length: { maximum: 2000 }
end
