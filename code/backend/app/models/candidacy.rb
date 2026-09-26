# やりとり（募集×学生。design/designs/データベース.md の 8-5）。
# 応募・スカウトのどちらから始まっても同じ「やりとり」になる。状態の移り変わりは権限_バリデーション.md の 17-2-1 が正
class Candidacy < ApplicationRecord
  # 学生から見た状態の4つ（API設計.md の形E）。関係がないときの none は、やりとりがないときに窓口の返事で使う。
  # ⑦ の選択肢（my_status）にも使う
  MY_STATUSES = %w[none applied scouted matched].freeze
  # 企業から見たタグの6つ（API設計.md の 16-3 ㉑・形D）。計算は tag。⑦ の選択肢（candidacy_tag）に使う
  TAGS = %w[pending_application scouted matched declined passed failed].freeze

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
  # スカウトの未マッチ・見送りは、スカウト管理（S4。順6）に出す。
  # Django でいうと、Manager に filter(...) を返すメソッドを足すのにあたる
  scope :listed_in_student_candidacies, -> { application.or(where(status: %i[matched passed failed])) }

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
  # 応募（apply）と、順6 のスカウトへのマッチで使うので、外から呼べるようにしている
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

  # 企業がその募集で今押せるボタンの名前の一覧（形D の available_actions。API設計.md の 16-3-2）。
  # 状態遷移表（権限_バリデーション.md の 17-2-1）にしたがって、判定をここ1か所で行う。画面はここに入っているボタンだけを出す。
  # 窓口ができている操作だけを返す（PR202）。順6 で、やりとりがなく掲載中なら "scout" を、
  # 順11 で "decline"・"undo_decline"・"pass"・"fail" を足す
  def self.available_actions_for(job_posting, candidacy)
    return [] if candidacy.nil?

    actions = []
    actions << "match" if candidacy.can_match_by_company?
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
