# ⑦ GET /api/options（選択肢とマスタ）。詳しくは design/designs/API設計.md の 16-1-9、16-3 ⑦。
# 企業・学生で共通の「言葉の辞書」。画面側はこれを一度取って使い回し、自分では選択肢の表を持たない。
# 中身は、機能を作るたびに足していく（順1 で人数・業界・事業形態、順2 で募集に使うもの、順3 で学生プロフィールに使うもの。未決内容.md の 11-2）
module Api
  class OptionsController < ApplicationController
    # 新規登録の画面でも使うので、ログイン前でも使える
    allow_unauthenticated_access

    # 返事は app/views/api/options/show.json.jbuilder
    def show
      # 大分類の中に中分類を入れて返すので、中分類もまとめて読む（N+1問題を避ける。Django の prefetch_related にあたる）
      @job_major_categories = JobMajorCategory.ordered.includes(:job_middle_categories)
      # 工程（上流 → 下流の表示順）
      @work_processes = WorkProcess.ordered
      @technologies = Technology.ordered
      @industries = Industry.ordered
      @business_types = BusinessType.ordered
      @prefectures = Prefecture.ordered
      @universities = University.ordered
      # 学部の中に学科を入れて返すので、学科もまとめて読む
      @faculties = Faculty.ordered.includes(:departments)
      # プチ職業体験の講座（講座の表示順。順18）
      @job_trials = JobTrial.ordered
    end
  end
end
