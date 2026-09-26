require "rails_helper"

# メッセージのテスト。本文の決まり（権限_バリデーション.md の 17-3-4：2,000文字まで、空は不可）を確かめる
RSpec.describe Message, type: :model do
  it "本文が空なら保存できず、「本文を入力してください」になる" do
    message = build(:message, body: "")

    expect(message).not_to be_valid
    expect(message.errors.full_messages).to include("本文を入力してください")
  end

  it "本文が2,001文字なら保存できない" do
    expect(build(:message, body: "あ" * 2001)).not_to be_valid
  end

  it "本文が2,000文字なら保存できる" do
    expect(build(:message, body: "あ" * 2000)).to be_valid
  end
end
