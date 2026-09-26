require "rails_helper"

# 新規登録（CompanyRegistration・StudentRegistration。親は Registration）のテスト。
# アカウント・プロフィール・付属情報を1つのトランザクションで作ること、
# 誤りを一度にすべて返し、誤りがあれば何も作らないことを確かめる（API設計.md の 16-3 ⑤⑥、技術構成.md の 9-2。PR226）
RSpec.describe Registration, type: :model do
  # ステップ1（アカウント）の正しい入力
  let(:account) { { email: "new@example.com", password: "password", password_confirmation: "password" } }

  # 窓口と同じく、項目名付きの文にした誤り（「メールアドレスはすでに登録されています」など）。
  # to_hash は項目名をシンボル（:email）で返すので、窓口の返事（JSON）と同じ文字列（"email"）に直して比べる
  def error_messages(registration)
    registration.errors.to_hash(true).transform_keys(&:to_s)
  end

  describe CompanyRegistration do
    it "アカウント（種別は企業）・企業プロフィール・業界・事業形態を作る" do
      industry = create(:industry)
      business_type = create(:business_type)
      registration = described_class.new(
        account.merge(name: "株式会社サンプル", employee_size: "size_10_49", about: "30人ほどの会社です",
                      industry_ids: [ industry.id ], business_type_ids: [ business_type.id ])
      )

      expect(registration.save).to be(true)

      user = User.sole
      expect(user).to have_attributes(email: "new@example.com", role: "company")
      expect(user.authenticate("password")).to eq(user)
      expect(user.company_profile).to have_attributes(name: "株式会社サンプル", employee_size: "size_10_49", about: "30人ほどの会社です")
      expect(user.company_profile.industries).to eq([ industry ])
      expect(user.company_profile.business_types).to eq([ business_type ])
      expect(registration.user).to eq(user)
    end

    it "ステップ1だけ（会社情報を飛ばした）でも登録できる" do
      expect(described_class.new(account.merge(name: "株式会社サンプル")).save).to be(true)
      expect(CompanyProfile.sole.industries).to eq([])
    end

    it "アカウントとプロフィールの誤りを一度にすべて返し、何も作らない" do
      create(:company_user, email: "taken@example.com")
      registration = described_class.new(
        email: "taken@example.com", password: "short", password_confirmation: "different", name: ""
      )

      expect(registration.save).to be(false)
      expect(error_messages(registration)).to include(
        "email" => [ "メールアドレスはすでに登録されています" ],
        "password" => [ "パスワードは8文字以上で入力してください" ],
        "password_confirmation" => [ "パスワード（確認）とパスワードの入力が一致しません" ],
        "name" => [ "会社名を入力してください" ]
      )
      # 先に作った1件だけ
      expect([ User.count, CompanyProfile.count ]).to eq([ 1, 1 ])
    end

    it "確認用のパスワードが送られていなければ、一致しないものとして扱う" do
      registration = described_class.new(email: "new@example.com", password: "password", name: "株式会社サンプル")

      expect(registration.save).to be(false)
      expect(error_messages(registration).keys).to eq([ "password_confirmation" ])
    end

    it "業界にマスタにない番号があれば、アカウントも作らない" do
      registration = described_class.new(account.merge(name: "株式会社サンプル", industry_ids: [ 0 ]))

      expect(registration.save).to be(false)
      expect(error_messages(registration)).to eq("industry_ids" => [ "業界に選べない値が含まれています" ])
      expect(User.count).to eq(0)
    end

    it "渡したブロックは書き込みと同じトランザクションの中で呼ばれ、そこで失敗したら、すべて取り消される" do
      registration = described_class.new(account.merge(name: "株式会社サンプル", industry_ids: [ create(:industry).id ]))

      expect { registration.save { raise ActiveRecord::RecordInvalid } }.to raise_error(ActiveRecord::RecordInvalid)
      expect([ User.count, CompanyProfile.count, CompanyIndustry.count ]).to eq([ 0, 0, 0 ])
    end

    it "ブロックには、作ったアカウントが渡される" do
      received = nil

      described_class.new(account.merge(name: "株式会社サンプル")).save { |user| received = user }

      expect(received).to eq(User.sole)
    end
  end

  describe StudentRegistration do
    it "アカウント（種別は学生）・学生プロフィール・興味のある職種・出社できる都道府県・プログラミング歴を作る" do
      middle = create(:job_middle_category)
      prefecture = create(:prefecture)
      technology = create(:technology)
      registration = described_class.new(
        account.merge(
          name: "山田 太郎", activity_status: "job_hunting", grade: "undergrad_3",
          interested_job_middle_category_ids: [ middle.id ], commutable_prefecture_ids: [ prefecture.id ],
          skills: [
            { technology_id: technology.id, other_name: nil, years: 1.5, level: "v2" },
            { technology_id: nil, other_name: "Elm", years: 0.5, level: "v1" }
          ]
        )
      )

      expect(registration.save).to be(true)

      user = User.sole
      expect(user.role).to eq("student")
      profile = user.student_profile
      expect(profile).to have_attributes(name: "山田 太郎", activity_status: "job_hunting", grade: "undergrad_3")
      expect(profile.interested_job_middle_categories).to eq([ middle ])
      expect(profile.commutable_prefectures).to eq([ prefecture ])
      expect(profile.student_skills.map { |skill| [ skill.technology_id, skill.other_name, skill.level ] })
        .to eq([ [ technology.id, nil, "v2" ], [ nil, "Elm", "v1" ] ])
    end

    it "活動状況が空なら登録できない（ステップ2の活動状況は必須。権限_バリデーション.md の 17-3-5）" do
      registration = described_class.new(account.merge(name: "山田 太郎"))

      expect(registration.save).to be(false)
      expect(error_messages(registration)).to eq("activity_status" => [ "活動状況を入力してください" ])
      expect(User.count).to eq(0)
    end

    it "プログラミング歴の行の誤りは、マイページと同じ名前（skills[0].years）と文で返す" do
      registration = described_class.new(
        account.merge(name: "山田 太郎", activity_status: "job_hunting",
                      skills: [ { technology_id: create(:technology).id, years: 1.3, level: "v1" } ])
      )

      expect(registration.save).to be(false)
      expect(error_messages(registration)).to eq("skills[0].years" => [ "年数は0.5刻みで入力してください" ])
      expect([ User.count, StudentSkill.count ]).to eq([ 0, 0 ])
    end

    it "学生の名前の項目名は「氏名」（企業の「会社名」とは別）" do
      registration = described_class.new(account.merge(name: "", activity_status: "job_hunting"))

      expect(registration.save).to be(false)
      expect(error_messages(registration)).to eq("name" => [ "氏名を入力してください" ])
    end
  end
end
