# ⑩ POST /api/company/profile/icon（企業のアイコン）。詳しくは design/designs/API設計.md の 16-3 ⑩、技術構成.md の 9-3。
# 受け取って添付する処理は、学生のアイコンと共通（app/controllers/concerns/icon_upload.rb）
module Api
  module Company
    class ProfileIconsController < BaseController
      include IconUpload

      def create
        attach_icon(current_company)
      end
    end
  end
end
