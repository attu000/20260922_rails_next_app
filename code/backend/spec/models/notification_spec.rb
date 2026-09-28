require "rails_helper"

# 通知のテスト。学生の欄は空欄でもよいこと（PR323）、本文は必須であること、未読・新しい順の取り出し方を確かめる
RSpec.describe Notification, type: :model do
  it "学生の欄が空欄でも保存できる（運営からのお知らせのような、学生と関係ない通知のため）" do
    expect(build(:notification, student_profile: nil, link_path: nil)).to be_valid
  end

  it "本文が空なら保存できない" do
    expect(build(:notification, body: "")).not_to be_valid
  end

  it "unread は未読の通知だけを返す" do
    unread = create(:notification)
    create(:notification, read_at: Time.current)

    expect(Notification.unread).to eq([ unread ])
  end

  it "latest_first は新しい順に、同じ時刻なら番号の大きい順に並べる" do
    time = Time.zone.parse("2026-09-28 09:00")
    older = create(:notification, created_at: time - 1.hour)
    same_time_first = create(:notification, created_at: time)
    same_time_second = create(:notification, created_at: time)

    expect(Notification.latest_first).to eq([ same_time_second, same_time_first, older ])
  end
end
