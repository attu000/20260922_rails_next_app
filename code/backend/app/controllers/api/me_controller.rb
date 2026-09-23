# ③ GET /api/me（ログイン中の人）。詳しくは design/designs/API設計.md の 16-1-5、16-3 ③。
# 次の3つは、ここではなく共通の前処理（ApplicationController に差し込んだ部品）が行う。
# - 未ログインなら 401 を返す（画面側は、これを見てログイン画面へ移すか決める。16-1-6）
# - CSRF の合言葉の Cookie を付ける（どの画面も最初にこれを呼ぶので、最初の送信の前に合言葉がそろう。16-1-7）
# - 最終活動日を記録する（16-1-12）
module Api
  class MeController < ApplicationController
    # 返事は形A（app/views/api/me/show.json.jbuilder）
    def show
      @user = current_user
      @profile = current_company || current_student
    end
  end
end
