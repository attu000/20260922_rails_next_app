# テストで送る画像ファイルを作る関数。Django の SimpleUploadedFile にあたる。
# 画像のファイル（バイナリ）をリポジトリに置かずに済むよう、中身はここに Base64 で書き、テストの中で作る
module UploadHelper
  # 1×1 ピクセルの PNG と GIF の中身
  PNG_BYTES = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
  ).freeze
  GIF_BYTES = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7").freeze

  # 送信用のファイルを作る。multipart/form-data で送るときに params に入れる
  def upload_file(bytes, filename:, content_type:)
    Rack::Test::UploadedFile.new(StringIO.new(bytes), content_type, true, original_filename: filename)
  end

  def png_upload
    upload_file(PNG_BYTES, filename: "icon.png", content_type: "image/png")
  end

  # 中身は GIF で、名前と形式だけ PNG と偽ったもの。Active Storage が中身から GIF と判定して弾くはず
  def gif_disguised_as_png_upload
    upload_file(GIF_BYTES, filename: "icon.png", content_type: "image/png")
  end

  # PNG の中身の後ろを 0 で埋めて、2MB＋1バイトにしたもの（上限は CompanyProfile::ICON_MAX_BYTES）
  def too_large_png_upload
    padding = "\0".b * (CompanyProfile::ICON_MAX_BYTES + 1 - PNG_BYTES.bytesize)
    upload_file(PNG_BYTES + padding, filename: "big.png", content_type: "image/png")
  end
end

RSpec.configure do |config|
  config.include UploadHelper, type: :request
end
