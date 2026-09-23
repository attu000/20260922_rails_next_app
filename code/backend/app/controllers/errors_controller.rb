# /api/ の下の、存在しない URL を 404 の形で返す（API設計.md の 16-1-10）。
# config/routes.rb のいちばん最後の行から呼ばれる
class ErrorsController < ApplicationController
  def not_found
    render_not_found
  end
end
