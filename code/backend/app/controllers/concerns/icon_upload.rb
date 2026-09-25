# アイコンを受け取って添付する処理を、ここ1か所にまとめる（design/designs/API設計.md の 16-3 ⑩⑰、技術構成.md の 9-3）。
# 企業のアイコン（⑩）と学生のアイコン（⑰）は中身が同じなので、どちらの窓口もこれを呼ぶだけにする。
# アイコンだけは JSON ではなく multipart/form-data の icon（ファイル1つ）で受け取る
module IconUpload
  extend ActiveSupport::Concern

  private

  # record は企業プロフィールか学生プロフィール（どちらも IconAttachment を include している）
  def attach_icon(record)
    file = params[:icon]

    # 送られたものがファイルでなければ 422。
    # Active Storage は、文字列を渡されると「保存済みのファイルの番号」と解釈して別の処理をするため、先に弾く
    unless file.is_a?(ActionDispatch::Http::UploadedFile)
      record.errors.add(:icon, :blank)
      return render_unprocessable(record.errors)
    end

    # 添付して保存する。モデルの検証（形式・2MB）が動き、通らなければ保存されない。
    # 保存できれば、差し替える前の画像は Active Storage が裏側で消す（16-3 ⑩）
    if record.icon.attach(file)
      # 返事は app/views/api/shared/icon_upload.json.jbuilder
      @icon_owner = record
      render "api/shared/icon_upload", status: :ok
    else
      render_unprocessable(record.errors)
    end
  end
end
