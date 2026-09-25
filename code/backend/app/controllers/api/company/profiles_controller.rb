# ⑧ GET /api/company/profile（自社のプロフィール）と ⑨ PATCH /api/company/profile（保存）。
# 詳しくは design/designs/API設計.md の 16-3 ⑧⑨。学生なら 403 は親（BaseController）が返す
module Api
  module Company
    class ProfilesController < BaseController
      # ⑧ 表示。返事は app/views/api/company/profiles/show.json.jbuilder
      def show
        @company = current_company
      end

      # ⑨ 保存。保存の処理はモデルの update_profile に1つにまとめてある（技術構成.md の 9-2）
      def update
        @company = current_company

        if @company.update_profile(profile_params)
          # ⑧と同じ形で返す（16-3 ⑨）
          render :show, status: :ok
        else
          render_unprocessable(@company.errors)
        end
      end

      private

      # 受け取ってよい値だけを通す（strong parameters。Django の Serializer の fields にあたる）。
      # icon_url や user_id などを送られても、ここで捨てる
      def profile_params
        params.permit(:name, :employee_size, :business_description, :about,
                      industry_ids: [], business_type_ids: [])
      end
    end
  end
end
