require "rails_helper"

# 学生プロフィールまわりのデータベースの CHECK のテスト。
# モデルの検証をすり抜けても、データベースが「どちらか一方だけ」の決まりを守ることを確かめる。
# 詳しくは design/designs/データベース.md の 8-5 student_profiles・student_skills
RSpec.describe StudentProfile, type: :model do
  let(:profile) { create(:student_user).student_profile }
  let(:technology) { create(:technology) }

  describe "データベースの CHECK（プログラミング歴は、技術か「その他」の名前のどちらか一方だけ）" do
    # save(validate: false) は、モデルの検証を飛ばして保存する
    it "技術も「その他」の名前もない行は、データベースが拒否する" do
      skill = StudentSkill.new(student_profile: profile, level: :v1)

      expect { skill.save(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
    end

    it "技術と「その他」の名前の両方がある行は、データベースが拒否する" do
      skill = StudentSkill.new(student_profile: profile, technology: technology, other_name: "Elm", level: :v1)

      expect { skill.save(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe "データベースの CHECK（一覧の大学と大学名（その他）は、両方同時に入らない）" do
    # update_columns は、モデルの検証も保存前の処理も飛ばして、SQL を直接送る（Django の QuerySet.update() に近い）
    it "両方を入れようとすると、データベースが拒否する" do
      university = create(:university)

      expect { profile.update_columns(university_id: university.id, university_other_name: "海外の大学") }
        .to raise_error(ActiveRecord::CheckViolation)
    end
  end
end
