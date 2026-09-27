require "rails_helper"

# ⑤ POST /api/company_registrations（企業の新規登録）と ⑥ POST /api/student_registrations（学生の新規登録）のテスト。
# 誤りの細かい中身（まとめ方、項目名）は spec/models/registration_spec.rb で確かめる。
# 詳しくは design/designs/API設計.md の 16-3 ⑤⑥、技術構成.md の 9-2
RSpec.describe "新規登録（/api/company_registrations・/api/student_registrations）", type: :request do
  let(:account) { { email: "new@example.com", password: "password", password_confirmation: "password" } }

  # 登録する。ログイン前の画面から呼ぶので、ログインはしない。CSRF 対策は有効なので、合言葉を付ける
  def register(path, params)
    post path, params: params, headers: { "X-CSRF-Token" => csrf_token }, as: :json
  end

  describe "⑤ 企業の新規登録" do
    # ログインの必須テスト（技術構成.md の 3-3 D-1）と同じ形。登録の画面を開いたときも、最初に ③ を呼ぶ
    it "登録の画面を初めて開いた人が、そのまま登録できる" do
      get "/api/me"
      expect(response).to have_http_status(:unauthorized)
      token = cookies[CsrfProtection::COOKIE_NAME]

      post "/api/company_registrations",
           params: account.merge(name: "株式会社サンプル"),
           headers: { "X-CSRF-Token" => CGI.unescape(token) },
           as: :json

      expect(response).to have_http_status(:created)
    end

    it "201 と形A（ログイン中の人）を返し、そのままログインした状態になる" do
      register("/api/company_registrations", account.merge(name: "株式会社サンプル"))

      expect(response).to have_http_status(:created)
      user = User.sole
      expect(response.parsed_body).to eq(
        "id" => user.id, "role" => "company", "name" => "株式会社サンプル",
        "icon_url" => nil, "unread_notifications_count" => nil
      )

      get "/api/me"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(user.id)
    end

    it "会社情報（業界・事業形態・人数など）も一緒に作る" do
      industry = create(:industry)
      business_type = create(:business_type)

      register("/api/company_registrations",
               account.merge(name: "株式会社サンプル", employee_size: "size_10_49",
                             industry_ids: [ industry.id ], business_type_ids: [ business_type.id ]))

      profile = CompanyProfile.sole
      expect(profile.employee_size).to eq("size_10_49")
      expect(profile.industries).to eq([ industry ])
      expect(profile.business_types).to eq([ business_type ])
    end

    it "role に student を送っても、企業のアカウントになる（受け取らない）" do
      register("/api/company_registrations", account.merge(name: "株式会社サンプル", role: "student"))

      expect(User.sole.role).to eq("company")
      expect(StudentProfile.count).to eq(0)
    end

    it "誤りがあれば 422 で項目ごとに返し、何も作らず、ログインもしていない" do
      create(:company_user, email: "taken@example.com")

      register("/api/company_registrations",
               email: "taken@example.com", password: "short", password_confirmation: "short", name: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].keys).to contain_exactly("email", "password", "name")
      expect([ User.count, Session.count ]).to eq([ 1, 0 ])

      get "/api/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "合言葉なしは 403" do
      post "/api/company_registrations", params: account.merge(name: "株式会社サンプル"), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(User.count).to eq(0)
    end
  end

  describe "⑥ 学生の新規登録" do
    it "201 と形A を返し、ログインした状態になる。プロフィールと付属情報も作る" do
      middle = create(:job_middle_category)
      prefecture = create(:prefecture)
      technology = create(:technology)

      register("/api/student_registrations",
               account.merge(name: "山田 太郎", activity_status: "job_hunting", grade: "undergrad_3",
                             interested_job_middle_category_ids: [ middle.id ],
                             commutable_prefecture_ids: [ prefecture.id ],
                             skills: [ { technology_id: technology.id, other_name: nil, years: 1.5, level: "v2" } ]))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("role" => "student", "name" => "山田 太郎")
      profile = StudentProfile.sole
      expect(profile).to have_attributes(activity_status: "job_hunting", grade: "undergrad_3")
      expect(profile.interested_job_middle_categories).to eq([ middle ])
      expect(profile.commutable_prefectures).to eq([ prefecture ])
      expect(profile.student_skills.sole).to have_attributes(technology_id: technology.id, level: "v2")

      get "/api/me"
      expect(response.parsed_body["role"]).to eq("student")
    end

    it "活動状況が空なら 422「活動状況を入力してください」。何も作らない" do
      register("/api/student_registrations", account.merge(name: "山田 太郎"))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq("activity_status" => [ "活動状況を入力してください" ])
      expect(User.count).to eq(0)
    end

    it "プログラミング歴の行の誤りは skills[0].years の名前で返す（マイページと同じ）" do
      register("/api/student_registrations",
               account.merge(name: "山田 太郎", activity_status: "job_hunting",
                             skills: [ { technology_id: create(:technology).id, years: 1.3, level: "v1" } ]))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq("skills[0].years" => [ "年数は0.5刻みで入力してください" ])
    end

    it "role に company を送っても、学生のアカウントになる（受け取らない）" do
      register("/api/student_registrations", account.merge(name: "山田 太郎", activity_status: "job_hunting", role: "company"))

      expect(User.sole.role).to eq("student")
    end

    # 順9 で足した、働き方の好み（性格）の5軸。受け取る項目の一覧はマイページと共有している（PERMITTED_PARAMS）
    it "働き方の好みを送ると保存され、送らなかった軸は0（中央）になる" do
      register("/api/student_registrations",
               account.merge(name: "山田 太郎", activity_status: "job_hunting",
                             personality_pace: -1, personality_atmosphere: 2))

      expect(response).to have_http_status(:created)
      expect(StudentProfile.sole).to have_attributes(
        personality_pace: -1, personality_novelty: 0, personality_collaboration: 0,
        personality_decision: 0, personality_atmosphere: 2
      )
    end
  end
end
