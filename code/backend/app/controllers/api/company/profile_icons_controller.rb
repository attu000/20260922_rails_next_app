# ⑩ POST /api/company/profile/icon（企業のアイコン）。詳しくは design/designs/API設計.md の 16-3 ⑩、技術構成.md の 9-3。
# アイコンだけは JSON ではなく multipart/form-data の icon（ファイル1つ）で受け取る
module Api
  module Company
    class ProfileIconsController < BaseController
      def create
        @company = current_company
        file = params[:icon]

        # 送られたものがファイルでなければ 422。
        # Active Storage は、文字列を渡されると「保存済みのファイルの番号」と解釈して別の処理をするため、先に弾く
        unless file.is_a?(ActionDispatch::Http::UploadedFile)
          @company.errors.add(:icon, :blank)
          return render_unprocessable(@company.errors)
        end

        # 添付して保存する。モデルの検証（形式・2MB）が動き、通らなければ保存されない。
        # 保存できれば、差し替える前の画像は Active Storage が裏側で消す（16-3 ⑩）
        if @company.icon.attach(file)
          # 返事は app/views/api/company/profile_icons/create.json.jbuilder
          render :create, status: :ok
        else
          render_unprocessable(@company.errors)
        end
      end
    end
  end
end
