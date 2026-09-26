# スレッド（企業×学生。design/designs/データベース.md の 8-5）。
# メッセージは「募集ごと」ではなく「相手ごと」なので、企業と学生の組み合わせで1本だけ作る
class MessageThread < ApplicationRecord
  belongs_to :company_profile
  belongs_to :student_profile

  # スレッドの中のメッセージ
  has_many :messages

  # スレッド一覧（API設計.md の 16-3 ㊱㊴）の並び順。最後のメッセージの日時の新しい順。
  # 応募に企業がマッチしただけのスレッドは、メッセージがまだなく last_message_at が空なので、
  # 代わりにスレッドを作った日時で比べる（空のまま並べると、PostgreSQL では新しい順の先頭に居座るため。PR221）。
  # Django の order_by(Coalesce("last_message_at", "created_at").desc(), "-id") にあたる
  scope :recent_first, lambda {
    order(Arel.sql("COALESCE(message_threads.last_message_at, message_threads.created_at) DESC"), id: :desc)
  }

  # その企業とその学生のスレッドがあるか（募集詳細・企業詳細・学生詳細の has_message_thread。API設計.md の 16-3 ⑲⑳㉓）。
  # true なら、画面に「この企業とのメッセージ」「この学生とのメッセージ」のボタンを出す（ボタンは順7。PR213）。
  # スレッドはスカウトを送ったときか、応募がマッチしたときにできるので、スカウトが届いただけでも true になる。
  # 送れるかどうか（下の can_send?）とは別（権限_バリデーション.md の 17-2-3）。
  # Django の MessageThread.objects.filter(company_profile=企業, student_profile=学生).exists() にあたる
  def self.exists_between?(company_profile, student_profile)
    exists?(company_profile: company_profile, student_profile: student_profile)
  end

  # このスレッドで今メッセージを送れるか（チャットの can_send。API設計.md の 16-3 ㊲㊵、権限_バリデーション.md の 17-2-3）。
  # この企業の募集と、この学生とのやりとりに、マッチ以降（マッチ・合格・不合格）が1つでもあれば true。
  # 募集の状態は見ない（一度マッチしていれば、募集が終了しても会話は続けられる）。
  # 画面の送信欄を使えるかの判定と、送るときの確かめの両方でこれを使う
  def can_send?
    Candidacy.after_match
             .joins(:job_posting)
             .exists?(student_profile_id: student_profile_id, job_postings: { company_profile_id: company_profile_id })
  end

  # ㊳㊶ メッセージを送る（API設計.md の 16-3-7）。窓口はこれを呼ぶだけにする（技術構成.md の 9-1-1 の4）。
  # - 送れない（マッチ以降のやりとりがない）なら、ConflictError を投げる（窓口では 409）
  # - 本文に誤りがあれば、保存せずに、誤り（errors）入りのメッセージを返す（窓口では 422）
  # - 保存できたら、保存したメッセージを返す
  def post_message(sender_user, body)
    # 状態を先に確かめる。送信欄を使えるかの判定と同じ can_send? を使う
    raise ConflictError unless can_send?

    message = messages.build(sender_user: sender_user, body: body)
    return message unless message.valid?

    # メッセージと、スレッドの最後のメッセージの日時を、まとめて書き込む（Django の transaction.atomic() にあたる）
    transaction do
      message.save!
      update!(last_message_at: message.created_at)
    end
    message
  end
end
