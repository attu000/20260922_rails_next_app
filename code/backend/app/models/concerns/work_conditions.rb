# 稼働条件の選択肢と検証を、ここ1か所にまとめる（design/designs/技術構成.md の 9-1）。
# 募集（企業の下限）と学生プロフィール（学生の上限）で、同じ物差しを使う（その他決め事.md の 5-6）。
# ⑦ GET /api/options が返す選択肢も、ここの定数から作る。
# Django でいえば、複数のモデルに同じ choices とバリデーションを持たせる Mixin にあたる
module WorkConditions
  extend ActiveSupport::Concern

  # 週の稼働日数
  WORK_DAYS_PER_WEEK = [ 1, 2, 3, 4, 5 ].freeze
  # 1日の稼働時間
  WORK_HOURS_PER_DAY = [ 2, 3, 4, 5, 6, 8 ].freeze
  # 継続期間（月）
  DURATION_MONTHS = [ 1, 3, 6, 9, 12 ].freeze

  class_methods do
    # 稼働条件の3つの数値が、選択肢のどれかであることを確かめる。すべて任意なので空欄は許す。
    # 列の名前は募集（min_work_days_per_week）と学生（work_days_per_week）で違うので、名前を受け取る
    def validates_work_conditions(days:, hours:, months:)
      validates days, inclusion: { in: WORK_DAYS_PER_WEEK }, allow_nil: true
      validates hours, inclusion: { in: WORK_HOURS_PER_DAY }, allow_nil: true
      validates months, inclusion: { in: DURATION_MONTHS }, allow_nil: true
    end
  end
end
