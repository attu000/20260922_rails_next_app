# ⑥ POST /api/student_registrations（学生の新規登録）。
# 詳しくは design/designs/API設計.md の 16-3 ⑥、技術構成.md の 9-2
module Api
  class StudentRegistrationsController < ApplicationController
    # ログイン前に使う
    allow_unauthenticated_access only: :create

    # 登録の処理はモデルの StudentRegistration に1つにまとめてある（PR226）。
    # 登録できたら自動でログインした状態にし、201 と形A（ログインと同じ app/views/api/me/show.json.jbuilder）を返す
    def create
      registration = StudentRegistration.new(registration_params)

      # ログインした状態にする処理（sessions を作り、Cookie を付ける）をブロックで渡す。
      # アカウント・プロフィールと同じトランザクションの中で呼ばれる（技術構成.md の 9-2）
      if registration.save { |user| start_new_session_for(user) }
        @user = current_user
        @profile = current_student
        render "api/me/show", status: :created
      else
        render_unprocessable(registration.errors)
      end
    end

    private

    # 受け取ってよい値だけを通す（strong parameters）。アカウントの3つと、マイページの保存と同じ項目。
    # role（種別）や user_id などを送られても、ここで捨てる（この窓口で企業のアカウントは作れない）。
    # 利用規約の同意（terms_agreed）は【仕上げ】で足す
    def registration_params
      params.permit(:email, :password, :password_confirmation, *Student::ProfilesController::PERMITTED_PARAMS)
    end
  end
end
