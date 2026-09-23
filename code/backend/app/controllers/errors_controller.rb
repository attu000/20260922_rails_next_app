# /api/ の下の、存在しない URL を 404 の形で返す（API設計.md の 16-1-10）。
# config/routes.rb のいちばん最後の行から呼ばれる
class ErrorsController < ApplicationController
  # 未ログインでも 404 を返す（外さないと、ログインの確認で先に 401 になる）
  allow_unauthenticated_access

  def not_found
    render_not_found
  end
end
