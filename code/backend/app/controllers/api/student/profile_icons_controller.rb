# ⑰ POST /api/student/profile/icon（学生のアイコン）。中身は⑩と同じ（design/designs/API設計.md の 16-3 ⑰）。
# 受け取って添付する処理は、企業のアイコンと共通（app/controllers/concerns/icon_upload.rb）
module Api
  module Student
    class ProfileIconsController < BaseController
      include IconUpload

      def create
        attach_icon(current_student)
      end
    end
  end
end
