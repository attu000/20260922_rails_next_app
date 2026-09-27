# やりとり（募集×学生。design/designs/データベース.md の 8-5）。
# 応募・スカウトのどちらから始まっても同じ「やりとり」になる。状態の移り変わりは権限_バリデーション.md の 17-2-1 が正
class Candidacy < ApplicationRecord
  # 学生から見た状態の4つ（API設計.md の形E）。関係がないときの none は、やりとりがないときに窓口の返事で使う。
  # ⑦ の選択肢（my_status）にも使う
  MY_STATUSES = %w[none applied scouted matched].freeze
  # 企業から見たタグの6つ（API設計.md の 16-3 ㉑・形D）。計算は tag。⑦ の選択肢（candidacy_tag）に使う
  TAGS = %w[pending_application scouted matched declined passed failed].freeze
  # マッチ以降の状態（マッチ・合格・不合格）。絞り込みの after_match と、1件ずつ確かめる after_match? で使う
  AFTER_MATCH_STATUSES = %i[matched passed failed].freeze

  belongs_to :job_posting
  belongs_to :student_profile

  # 応募理由・マッチ理由
  has_many :candidacy_reasons
  # スカウトから始まったやりとりなら、そのスカウト文の記録
  has_one :scout_message

  # 発生元と状態。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。
  # 状態は、【コア】で使わない見送り・合格・不合格も含めて、5つを最初から書く（技術構成.md の 9-1-1 の3）
  enum :origin, {
    application: 0,
    scout: 1
  }, validate: true
  enum :status, {
    unmatched: 0,
    matched: 1,
    declined: 2,
    passed: 3,
    failed: 4
  }, validate: true

  # 学生の募集管理（S3。API設計.md の 16-3 ㉞）に出すやりとり（データベース.md の 8-7）。
  # 発生元が応募のもの（状態は問わない）と、発生元がスカウトで状態がマッチ・合格・不合格のもの。
  # スカウトの未マッチ・見送りは、スカウト管理（S4）に出す（下の listed_in_student_scouts）。
  # Django でいうと、Manager に filter(...) を返すメソッドを足すのにあたる
  scope :listed_in_student_candidacies, -> { application.or(where(status: %i[matched passed failed])) }
  # 学生のスカウト管理（S4。API設計.md の 16-3 ㉟）に出すやりとり。
  # 発生元がスカウトで、状態が未マッチか見送りのもの（見送りは学生に見せないので、「スカウトあり」のまま出す）
  scope :listed_in_student_scouts, -> { scout.where(status: %i[unmatched declined]) }
  # 企業の学生検索（C5）から外すやりとり（PR220）。「未対応応募（応募の未マッチ）」以外のすべて。
  # スカウトから始まったもの（未マッチ・見送り・マッチ以降）と、応募から始まって見送り・マッチ以降になったもの。
  # 検索はスカウトする相手を探すためのものなので、もうスカウトした・見送った・マッチした学生は出さない
  scope :excluded_from_student_search, -> { scout.or(where.not(status: :unmatched)) }
  # マッチ以降（マッチ・合格・不合格）のやりとり。メッセージを送れるかの判定に使う（権限_バリデーション.md の 17-2-3）
  scope :after_match, -> { where(status: AFTER_MATCH_STATUSES) }
  # 企業の候補者一覧（C4。API設計.md の 16-3 ㉑）に既定で出すやりとり。状態が未マッチかマッチのもの。
  # 見送り・合格・不合格は既定で隠し、show_all のときだけ出す（ページ設計.md の 6-5 C4）
  scope :listed_in_company_candidacies, -> { where(status: %i[unmatched matched]) }

  # ㉛ 応募（API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1）。窓口はこれを呼ぶだけにする（技術構成.md の 9-1-1 の4）。
  # まだないやりとりを作るので、クラスのメソッドにしている（PR204）。
  # - 今の状態ではできない（募集が掲載中でない、この募集とのやりとりがもうある）なら、ConflictError を投げる（窓口では 409）
  # - 応募理由に誤りがあれば、保存せずに、誤り（errors）入りのやりとりを返す（窓口では 422）
  # - 保存できたら、保存したやりとりを返す
  def self.apply(student_profile, job_posting, reasons)
    # 状態を先に確かめる。終了した募集への応募は、理由を直しても通らないため
    raise ConflictError unless job_posting.published?
    raise ConflictError if exists?(student_profile: student_profile, job_posting: job_posting)

    candidacy = new(student_profile: student_profile, job_posting: job_posting, origin: :application, status: :unmatched)
    candidacy.validate_reasons(reasons)
    return candidacy if candidacy.errors.any?

    # やりとり、応募理由、理由の組の写しを、まとめて書き込む（Django の transaction.atomic() にあたる）
    transaction do
      candidacy.save!
      candidacy.save_reasons!(reasons)
    end
    # 【強み】の順12 で、ここに「トランザクションが確定したら推薦のジョブを呼ぶ」処理を足す（技術構成.md の 9-1-1 の4）
    candidacy
  rescue ActiveRecord::RecordNotUnique
    # 同時に2回押され、データベースの「同じ募集×学生のやりとりは1件だけ」に弾かれた。応募済みと同じ扱いにする
    raise ConflictError
  end

  # 付いている応募理由・マッチ理由の名前の一覧（例：["business", "culture"]）。学生詳細の candidacy.reasons と同じ中身（API設計.md の形D）。
  # エラーの文を作るとき、Rails は項目の今の値を読みに行く（文の中に %{value} で差し込めるようにするため）。
  # 応募理由の誤りは reasons の名前で入れるので、この名前で読めないと止まってしまう（学生プロフィールの skills と同じ）
  def reasons
    candidacy_reasons.map(&:reason)
  end

  # 応募理由・マッチ理由が正しいかを確かめる。誤りは errors の reasons に入れる（権限_バリデーション.md の 17-3-4）。
  # 文言は、業界や技術の番号の一覧と同じもの（「応募理由に選べない値が含まれています」など）。
  # 応募（apply）と、スカウトへのマッチ（match_by_student）で使う
  def validate_reasons(reasons)
    reasons = Array(reasons).map(&:to_s)
    return errors.add(:reasons, :blank) if reasons.empty?

    errors.add(:reasons, :not_selectable) unless (reasons - CandidacyReason.reasons.keys).empty?
    errors.add(:reasons, :duplicated) if reasons.uniq.size != reasons.size
  end

  # 応募理由の行と、理由の組の写し（reason_mask）を保存する。validate_reasons で確かめてから、トランザクションの中で呼ぶ。
  # 写しは応募理由と同じトランザクションで書く決まり（データベース.md の 8-5 candidacies）
  def save_reasons!(reasons)
    reasons = Array(reasons).map(&:to_s)
    reasons.each { |reason| candidacy_reasons.create!(reason: reason) }
    update!(reason_mask: CandidacyReason.mask_for(reasons))
  end

  # ㉔ スカウト（API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1）。窓口はこれを呼ぶだけにする（技術構成.md の 9-1-1 の4）。
  # 応募（apply）と同じく、まだないやりとりを作るので、クラスのメソッドにしている（PR204）。
  # 名前を scout にしないのは、enum の origin が自動で作る絞り込み Candidacy.scout（発生元がスカウトのもの）を
  # 上書きしてしまうため（PR215）
  # - 今の状態ではできない（募集が掲載中でない、この募集×学生のやりとりがもうある）なら、ConflictError を投げる（窓口では 409）
  # - スカウト文に誤りがあれば、保存せずに、誤り（errors）入りのやりとりを返す（窓口では 422）
  # - 保存できたら、保存したやりとりを返す
  def self.send_scout(job_posting, student_profile, body)
    # 状態を先に確かめる。押せるボタンの判定と同じ can_scout? を使う
    raise ConflictError unless can_scout?(job_posting, find_by(job_posting: job_posting, student_profile: student_profile))

    candidacy = new(job_posting: job_posting, student_profile: student_profile, origin: :scout, status: :unmatched)
    candidacy.validate_scout_body(body)
    return candidacy if candidacy.errors.any?

    # やりとり、スレッド（なければ）、メッセージ、スカウトメッセージを、まとめて書き込む（技術構成.md の 9-2）
    transaction do
      candidacy.save!
      # スレッドは企業×学生で1本。同じ企業の別の募集で、先にスカウトやマッチをしていれば、もうある（マッチと同じ）
      thread = MessageThread.create_or_find_by!(company_profile_id: job_posting.company_profile_id, student_profile_id: student_profile.id)
      # 送った人は、その募集の企業のアカウント（今は1社1アカウント）
      message = thread.messages.create!(sender_user: job_posting.company_profile.user, body: body)
      candidacy.create_scout_message!(message: message)
      # スレッド一覧の並び替え用（順7）
      thread.update!(last_message_at: message.created_at)
    end
    candidacy
  rescue ActiveRecord::RecordNotUnique
    # 同時に2回押され、データベースの「同じ募集×学生のやりとりは1件だけ」に弾かれた。スカウト済みと同じ扱いにする
    raise ConflictError
  end

  # 企業がこの募集で、この学生にスカウトできるか（㉔。権限_バリデーション.md の 17-2-1）。
  # やりとりがまだなく、募集が掲載中なら true。押せるボタンの判定と、スカウトを送るときの確かめの両方で使う
  def self.can_scout?(job_posting, candidacy)
    candidacy.nil? && job_posting.published?
  end

  # スカウト文が正しいかを確かめる。決まり（空は不可・2,000文字まで）は、メッセージの本文と同じなので、
  # Message モデルの確かめをそのまま使い、誤りを項目名「スカウト文」（body）に付け替えて、このやりとりの errors に取り込む。
  # Django でいうと、別のフォームの errors を、キーの名前を変えて自分の errors に写すのにあたる
  def validate_scout_body(body)
    message = Message.new(body: body)
    message.validate
    # スレッドや送った人がまだないことの誤りは要らないので、本文の誤りだけを取り込む
    message.errors.where(:body).each { |error| errors.import(error, attribute: :body) }
  end

  # 企業がその募集で今押せるボタンの名前の一覧（形D の available_actions。API設計.md の 16-3-2）。
  # 状態遷移表（権限_バリデーション.md の 17-2-1）にしたがって、判定をここ1か所で行う。画面はここに入っているボタンだけを出す。
  # 並びは形D の一覧と同じ（scout、match、decline、undo_decline、pass、fail）
  def self.available_actions_for(job_posting, candidacy)
    actions = []
    actions << "scout" if can_scout?(job_posting, candidacy)
    return actions if candidacy.nil?

    actions << "match" if candidacy.can_match_by_company?
    actions << "decline" if candidacy.can_decline?
    actions << "undo_decline" if candidacy.can_undo_decline?
    actions << "pass" if candidacy.can_mark_passed?
    actions << "fail" if candidacy.can_mark_failed?
    actions
  end

  # 企業がこのやりとりにマッチできるか（㉖。権限_バリデーション.md の 17-2-1）。
  # 応募から始まり、状態が未マッチか見送りで、募集が掲載中なら true。
  # スカウトから始まったやりとりは、学生が応じたときにマッチするので、企業はマッチできない（その他決め事.md の 5-1）
  def can_match_by_company?
    application? && (unmatched? || declined?) && job_posting.published?
  end

  # ㉖ 企業が応募にマッチする（API設計.md の 16-3-6）。窓口はこれを呼ぶだけにする（技術構成.md の 9-1-1 の4）。
  # 今あるやりとりを変えるので、インスタンスのメソッドにしている（PR204）。
  # できない状態なら ConflictError を投げる（窓口では 409）。押せるボタンの判定と同じ can_match_by_company? で確かめるので、
  # 「ボタンは出ているのに押すと 409」という食い違いは起きない
  def match
    raise ConflictError unless can_match_by_company?

    # やりとりの更新と、スレッドの作成（まだなければ）を1つのトランザクションで行う（技術構成.md の 9-2）
    transaction do
      update!(status: :matched, matched_at: Time.current)
      # スレッドは企業×学生で1本。同じ企業の別の募集で先にマッチしていれば、もうある。
      # create_or_find_by! は「作ってみて、1本だけの決まりに弾かれたら、今あるものを使う」。同時に2つマッチされても重複しない
      MessageThread.create_or_find_by!(company_profile_id: job_posting.company_profile_id, student_profile_id: student_profile_id)
    end
  end

  # 学生がこのやりとりにマッチできるか（㉜。権限_バリデーション.md の 17-2-1）。
  # スカウトから始まり、状態が未マッチか見送りで、募集が掲載中なら true（企業側の can_match_by_company? と対になるもの）。
  # 応募から始まったやりとりは、企業が応じたときにマッチするので、学生はマッチできない（その他決め事.md の 5-1）
  def can_match_by_student?
    scout? && (unmatched? || declined?) && job_posting.published?
  end

  # ㉜ 学生がスカウトにマッチする（API設計.md の 16-3-6）。窓口はこれを呼ぶだけにする（技術構成.md の 9-1-1 の4）。
  # 今あるやりとりを変えるので、インスタンスのメソッドにしている（PR204）。企業側の match と区別して、この名前にしている。
  # - できない状態なら ConflictError を投げる（窓口では 409）
  # - マッチ理由に誤りがあれば、何も保存せずに false を返す（誤りは errors に入る。窓口では 422）
  # - 保存できたら true を返す
  # スレッドは、スカウトを送ったときにもうできているので、ここでは作らない（16-3-6 の表）
  def match_by_student(reasons)
    raise ConflictError unless can_match_by_student?

    # マッチ理由は、応募理由と同じ項目・同じ確かめ（技術構成.md の 9-2）
    validate_reasons(reasons)
    return false if errors.any?

    # 状態の更新と、マッチ理由・理由の組の写しを、まとめて書き込む
    transaction do
      update!(status: :matched, matched_at: Time.current)
      save_reasons!(reasons)
    end
    # 【強み】の順12 で、ここに「トランザクションが確定したら推薦のジョブを呼ぶ」処理を足す（技術構成.md の 9-1-1 の4）
    true
  end

  # ㉗〜㉚ 見送り・見送りの取り消し・合格・不合格（API設計.md の 16-3-6、権限_バリデーション.md の 17-2-1。順11）。
  # 企業が一覧を整理するための操作で、発生元と募集の状態は問わない（終了した募集でもできる）。
  # どれも状態を1つ書き換えるだけで、ほかの表は触らないので、トランザクションで囲まない。
  # できない状態なら ConflictError を投げる（窓口では 409）。押せるボタンの判定と同じ can_〜? で確かめる

  # 見送れるか（㉗）。状態が未マッチなら true（応募・スカウトとも）
  def can_decline?
    unmatched?
  end

  # 見送りを取り消せるか（㉘）。状態が見送りなら true（応募・スカウトとも）
  def can_undo_decline?
    declined?
  end

  # 合格にできるか（㉙）。状態がマッチか不合格なら true（不合格からの付け替えを含む）
  def can_mark_passed?
    matched? || failed?
  end

  # 不合格にできるか（㉚）。状態がマッチか合格なら true（合格からの付け替えを含む）
  def can_mark_failed?
    matched? || passed?
  end

  # ㉗ 見送る。状態を見送りにする
  def decline
    raise ConflictError unless can_decline?

    update!(status: :declined)
  end

  # ㉘ 見送りを取り消す。状態を未マッチに戻す（候補者一覧の既定の表示に戻る）
  def undo_decline
    raise ConflictError unless can_undo_decline?

    update!(status: :unmatched)
  end

  # ㉙ 合格として保存する。マッチした日時はそのまま残す。
  # 名前を pass・fail にしないのは、Ruby に最初からある fail（raise の別名）を上書きしてしまうため。
  # 合格も不合格に合わせて mark_ を付ける（PR269）
  def mark_passed
    raise ConflictError unless can_mark_passed?

    update!(status: :passed)
  end

  # ㉚ 不合格として保存する。マッチした日時はそのまま残す
  def mark_failed
    raise ConflictError unless can_mark_failed?

    update!(status: :failed)
  end

  # このやりとりがマッチ以降（マッチ・合格・不合格）か。
  # 候補者一覧（API設計.md の 16-3 ㉑）の行に「メッセージ」のボタンを出すかに使う（PR224）。
  # 判定を画面側に書かず、ここで計算して返す（16-1-9）。Django のモデルの @property で status in (...) を返すのにあたる
  def after_match?
    AFTER_MATCH_STATUSES.include?(status.to_sym)
  end

  # 企業から見た、やりとりの状態のタグ（API設計.md の 16-3 ㉑・形D）。
  # 「未対応応募」は発生元と状態の組み合わせに付けた名前なので、画面側では組み立てず、ここで計算して返す（16-1-9）
  def tag
    return status unless unmatched?

    application? ? "pending_application" : "scouted"
  end

  # 学生から見た状態（API設計.md の形E、データベース.md の 8-7）。
  # 見送り・合格・不合格は学生に見せないので、見送りは応募済み・スカウトありのまま、合格・不合格はマッチ済みに見せる
  def my_status
    return "matched" if matched? || passed? || failed?

    application? ? "applied" : "scouted"
  end
end
