require "rails_helper"

# スカウトメッセージのテスト。データベースの決まり（データベース.md の 8-5 scout_messages）を確かめる。
# データベースが一度拒否すると、そのテストの中ではそれ以上 SQL を送れなくなるので、1つのテストで1回だけ確かめる
RSpec.describe ScoutMessage, type: :model do
  describe "データベースの制約" do
    it "同じやりとりに2つ目のスカウト文を作ると、データベースが拒否する" do
      candidacy = create(:candidacy, :scout)
      described_class.create!(candidacy: candidacy, message: create(:message))

      expect {
        described_class.create!(candidacy: candidacy, message: create(:message))
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "同じメッセージを2つのスカウトに使うと、データベースが拒否する" do
      message = create(:message)
      described_class.create!(candidacy: create(:candidacy, :scout), message: message)

      expect {
        described_class.create!(candidacy: create(:candidacy, :scout), message: message)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
