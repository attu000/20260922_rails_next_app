# 企業プロフィール（design/designs/データベース.md の 8-5）。
# 必須は会社名だけで、新規登録でも企業プロフィール編集でも同じ（その他決め事.md の 5-9）
class CompanyProfile < ApplicationRecord
  # 番号の一覧の確認（validate_master_ids）。募集・学生プロフィールと共通（concerns/master_ids_validation.rb）
  include MasterIdsValidation
  # アイコンの添付と検証（形式・2MB）。学生プロフィールと共通（concerns/icon_attachment.rb）
  include IconAttachment

  belongs_to :user

  # 自社の募集。窓口では、自社の募集の中からだけ番号で探す（見てよい範囲の外は 404。API設計.md の 16-1-10）
  has_many :job_postings
  # 学生とのスレッド
  has_many :message_threads

  # 業界・事業形態（どちらも任意、複数）。Django の ManyToManyField(through=...) にあたる。
  # 会社の紹介として表示するだけで、検索・おすすめには使わない（使うのは募集の値。その他決め事.md の 5-8）
  has_many :company_industries
  has_many :industries, through: :company_industries
  has_many :company_business_types
  has_many :business_types, through: :company_business_types

  # 人数。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）。範囲外の値は検証エラーにする。任意なので空欄は許す
  enum :employee_size, {
    size_1_9: 0,
    size_10_49: 1,
    size_50_99: 2,
    size_100_299: 3,
    size_300_999: 4,
    size_1000_plus: 5
  }, validate: { allow_nil: true }

  # 形式と長さの決まり（権限_バリデーション.md の 17-3-4）
  validates :name, presence: true, length: { maximum: 100 }
  validates :business_description, :about, length: { maximum: 2000 }

  # 企業プロフィールの保存（⑨ PATCH /api/company/profile）。窓口はこれを呼ぶだけにする（技術構成.md の 9-2）。
  # 保存できたら true、入力に誤りがあれば false を返す（誤りは errors に入る）。
  #
  # 「先に全部確かめてから、トランザクションの中で書き込む」順番にしている。
  # Rails では、保存済みのレコードに industry_ids を代入すると、保存を待たずにその場で中間テーブルが書き換わる。
  # 確かめる前に代入すると、会社名が空欄で失敗したのに業界だけ変わる、という半端な状態が残るため
  def update_profile(attributes)
    attributes = attributes.to_h.symbolize_keys
    industry_ids = attributes.delete(:industry_ids)
    business_type_ids = attributes.delete(:business_type_ids)

    # ① 本体の値（会社名など）を、保存せずにモデルに入れるだけ
    assign_attributes(attributes)

    # ② 検証する。③ 番号の一覧を確かめる（Rails に任せると、存在しない番号が 404 になるため。17-3-4 では 422）
    valid?
    validate_master_ids(:industry_ids, industry_ids, Industry)
    validate_master_ids(:business_type_ids, business_type_ids, BusinessType)

    # ④ 誤りが1つでもあれば、何も書き込まずに終わる
    return false if errors.any?

    # ⑤ まとめて書き込む。途中で失敗したら、すべて取り消す（Django の transaction.atomic() にあたる）
    transaction do
      save!
      # 中間テーブルを、送られた一覧でまるごと置き換える（16-3 ⑨）。送られなかった項目は変えない
      self.industry_ids = industry_ids unless industry_ids.nil?
      self.business_type_ids = business_type_ids unless business_type_ids.nil?
    end
    # 【強み】の順12 で、ここに「トランザクションが確定したら推薦のジョブを呼ぶ」処理を足す（技術構成.md の 9-1-1 の4）
    true
  end
end
