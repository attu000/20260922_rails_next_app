# 性格・カルチャーの5軸を、ここ1か所にまとめる（design/designs/その他決め事.md の 5-5）。
# 学生の働き方の好み（student_profiles の personality_。画面での呼び名は PR233）と、募集のカルチャー（job_postings の culture_）で、同じ軸を使う。
# ⑦ GET /api/options が返す5軸と、⑲ 募集詳細が返す自分の働き方の好み（順10）も、ここの AXES を使う。
# Django でいえば、複数のモデルに同じバリデーションを持たせる Mixin にあたる
module CultureAxes
  extend ActiveSupport::Concern

  # ① 進め方 ② 新しさ ③ 周囲との関わり ④ 決め手 ⑤ 職場の雰囲気
  AXES = %i[pace novelty collaboration decision atmosphere].freeze
  # 値の範囲（負＝左、正＝右、0＝中央）。データベースの CHECK と同じ
  MIN = -2
  MAX = 2

  class_methods do
    # 5つの列（prefix_pace など）が、−2 以上 2 以下の整数であることを確かめる。
    # 列の名前の頭は学生（personality）と募集（culture）で違うので、受け取る。
    # 空欄も許さない（データベースで空欄不可、初期値は中央）。
    # only_integer は、型を変える前の値を見るので、1.5 を 1 に丸めずに誤りにする
    def validates_culture_axes(prefix)
      columns = AXES.map { |axis| :"#{prefix}_#{axis}" }
      validates(*columns, numericality: {
        only_integer: true,
        greater_than_or_equal_to: MIN,
        less_than_or_equal_to: MAX
      })
    end
  end
end
