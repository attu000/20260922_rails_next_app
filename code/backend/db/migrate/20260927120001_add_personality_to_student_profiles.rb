# student_profiles（学生プロフィール）に、性格の5軸の列を足す。design/designs/データベース.md の 8-5、軸の中身はその他決め事.md の 5-5。
# 画面での呼び名は「働き方の好み」（PR233）。列の名前は設計書どおり personality_ のまま。
# 値は −2〜2（負＝左、正＝右、0＝中央）。初期値は中央。企業の募集のカルチャー（job_postings の culture_）と同じ軸
class AddPersonalityToStudentProfiles < ActiveRecord::Migration[8.1]
  AXES = %i[pace novelty collaboration decision atmosphere].freeze

  def change
    # ① 進め方 ② 新しさ ③ 周囲との関わり ④ 決め手 ⑤ 職場の雰囲気。limit: 2 で smallint になる。
    # 空欄不可で初期値があるので、今ある学生にも 0（中央）が入る
    AXES.each do |axis|
      add_column :student_profiles, :"personality_#{axis}", :integer, limit: 2, null: false, default: 0
    end

    # 範囲の外の値は、データベースでも受け付けない
    AXES.each do |axis|
      add_check_constraint :student_profiles, "personality_#{axis} BETWEEN -2 AND 2",
                           name: "student_profiles_personality_#{axis}_range"
    end
  end
end
