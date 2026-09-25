# アイコンの添付と検証を、ここ1か所にまとめる（design/designs/技術構成.md の 9-3）。
# 企業プロフィールと学生プロフィールで、同じ決まり（PNG・JPEG・WebP、2MB まで）を使う（権限_バリデーション.md の 17-3-4）。
# Django でいえば、ImageField と、その検証を持つ抽象モデル（Mixin）にあたる
module IconAttachment
  extend ActiveSupport::Concern

  # アイコンで受け付ける形式と大きさ
  ICON_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  ICON_MAX_BYTES = 2.megabytes

  included do
    # アイコン。列は足さず、Active Storage のテーブルで持つ（Django の ImageField にあたる）
    has_one_attached :icon

    validate :icon_must_be_acceptable
  end

  private

  # アイコンの形式と大きさ。Rails には添付ファイルの検証が標準で入っていないので、自分で書く（技術構成.md の 9-3）。
  # 形式は、ファイル名の拡張子ではなく、Active Storage がファイルの中身から判定したものを使う
  def icon_must_be_acceptable
    return unless icon.attached?

    errors.add(:icon, :invalid_content_type) unless icon.blob.content_type.in?(ICON_CONTENT_TYPES)
    errors.add(:icon, :file_too_large) if icon.blob.byte_size > ICON_MAX_BYTES
  end
end
