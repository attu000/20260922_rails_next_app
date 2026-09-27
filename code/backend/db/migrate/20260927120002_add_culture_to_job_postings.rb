# job_postings（募集）に、カルチャーグラフの5軸の列を足す。design/designs/データベース.md の 8-5、軸の中身はその他決め事.md の 5-5。
# 値は −2〜2（負＝左、正＝右、0＝中央）。初期値は中央。学生の性格（student_profiles の personality_）と同じ軸。
# 常に必須だが、初期値が中央なので空になることはない（その他決め事.md の 5-9）
class AddCultureToJobPostings < ActiveRecord::Migration[8.1]
  AXES = %i[pace novelty collaboration decision atmosphere].freeze

  def change
    # ① 進め方 ② 新しさ ③ 周囲との関わり ④ 決め手 ⑤ 職場の雰囲気。limit: 2 で smallint になる。
    # 空欄不可で初期値があるので、今ある募集にも 0（中央）が入る
    AXES.each do |axis|
      add_column :job_postings, :"culture_#{axis}", :integer, limit: 2, null: false, default: 0
    end

    # 範囲の外の値は、データベースでも受け付けない
    AXES.each do |axis|
      add_check_constraint :job_postings, "culture_#{axis} BETWEEN -2 AND 2",
                           name: "job_postings_culture_#{axis}_range"
    end
  end
end
