# 新規登録（⑤ 企業・⑥ 学生。design/designs/API設計.md の 16-3 ⑤⑥、技術構成.md の 9-2）の共通の処理。
# 企業は CompanyRegistration、学生は StudentRegistration がこれを親にし、種別とプロフィールの種類だけを決める。
#
# 登録では、アカウント（users）とプロフィール（company_profiles・student_profiles）と付属情報を同時に作る。
# 表と1対1でない入力をまとめて確かめるので、表を持たないモデル（フォームオブジェクト）にしている（PR226）。
# Django でいえば、2つの ModelForm を1つのフォームにまとめたものにあたる。
#
# 「先に全部確かめてから、1つのトランザクションで書き込む」順番にしている。
# アカウントとプロフィールの誤り（メールアドレスと会社名など）を一度にすべて返し、片方だけ書き込まれることもないようにするため
class Registration
  # 表を持たないモデルに、errors や検証の仕組みを付ける
  include ActiveModel::Model

  # アカウント（users）の項目。これ以外はプロフィールの項目として扱う
  ACCOUNT_ATTRIBUTES = %i[email password password_confirmation].freeze

  # 作ったアカウントとプロフィール（save のあとに使う）
  attr_reader :user, :profile

  # attributes：画面から送られた、全ステップの入力（窓口で受け取ってよい値だけに絞ったもの）
  def initialize(attributes)
    attributes = attributes.to_h.symbolize_keys
    @account_attributes = attributes.slice(*ACCOUNT_ATTRIBUTES)
    # 確認用が送られていなくても「パスワード（確認）とパスワードの入力が一致しません」と出すため、空の文字列にする
    # （nil のままだと、has_secure_password は確認用との一致を確かめない）
    @account_attributes[:password_confirmation] = @account_attributes[:password_confirmation].to_s
    @profile_attributes = attributes.except(*ACCOUNT_ATTRIBUTES)
  end

  # 登録する。登録できたら true、入力に誤りがあれば false を返す（誤りは errors に入る）。
  # ブロックを渡すと、書き込みと同じトランザクションの中で、作ったアカウントを渡して呼ぶ。
  # 窓口は「ログインした状態にする処理」（sessions を作る）を渡す（sessions も同じトランザクションで作る。技術構成.md の 9-2）
  def save
    # ① アカウントとプロフィールを組み立てる。まだ保存しない
    @user = User.new(role: self.class::ROLE, **@account_attributes)
    @profile = self.class::PROFILE_CLASS.new(user: @user)

    # ② 両方を確かめ、誤りを1つにまとめる（項目名はそれぞれのモデルのものを使う。human_attribute_name）
    @user.valid?
    @profile.assign_profile(@profile_attributes)
    errors.clear
    [ @user, @profile ].each do |record|
      record.errors.each { |error| errors.import(error) }
    end

    # ③ 誤りが1つでもあれば、何も書き込まずに終わる
    return false if errors.any?

    # ④ まとめて書き込む。途中で失敗したら、すべて取り消す（Django の transaction.atomic() にあたる）。
    # アカウントを保存してから（番号が決まる）、プロフィールの本体と付属情報（中間テーブル・プログラミング歴）を書き込む
    ActiveRecord::Base.transaction do
      @user.save!
      @profile.write_profile!
      yield @user if block_given?
    end
    true
  rescue ActiveRecord::RecordNotUnique
    # 同時に同じメールアドレスで登録され、データベースの「メールアドレスは1つだけ」に弾かれた。登録済みと同じ扱いにする
    errors.add(:email, :taken)
    false
  end

  # エラーの文に使う項目名。アカウントの項目はアカウントの名前（「メールアドレス」など）、
  # それ以外はプロフィールの名前（企業なら「会社名」、学生なら「氏名」。プログラミング歴の行の名前もマイページと同じ）。
  # まとめた誤りの文を、元のモデルで確かめたときと同じ言葉にするため
  def self.human_attribute_name(attribute, options = {})
    if ACCOUNT_ATTRIBUTES.include?(attribute.to_s.to_sym)
      User.human_attribute_name(attribute, options)
    else
      self::PROFILE_CLASS.human_attribute_name(attribute, options)
    end
  end
end
