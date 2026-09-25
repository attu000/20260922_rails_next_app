require "rails_helper"

# ⑦ GET /api/options（選択肢とマスタ）のテスト。
# 詳しくは design/designs/API設計.md の 16-1-9、16-3 ⑦
RSpec.describe "選択肢とマスタ（GET /api/options）", type: :request do
  before do
    # 表示順どおりに並ぶかを見るため、表示順の大きいほうを先に作る
    create(:industry, name: "業界B", position: 2)
    create(:industry, name: "業界A", position: 1)
    create(:business_type, name: "自社サービス", position: 1)
  end

  it "ログインしていなくても 200 で返す" do
    get "/api/options"

    expect(response).to have_http_status(:ok)
  end

  it "人数の選択肢を、名前と日本語の表示名で返す" do
    get "/api/options"

    employee_sizes = response.parsed_body["enums"]["employee_size"]
    expect(employee_sizes.size).to eq(6)
    expect(employee_sizes.first).to eq("value" => "size_1_9", "label" => "1〜9人")
  end

  it "業界・事業形態を表示順で返す" do
    get "/api/options"

    masters = response.parsed_body["masters"]
    expect(masters["industries"].map { |industry| industry["name"] }).to eq(%w[業界A 業界B])
    expect(masters["business_types"].map { |business_type| business_type["name"] }).to eq(%w[自社サービス])
  end
end
