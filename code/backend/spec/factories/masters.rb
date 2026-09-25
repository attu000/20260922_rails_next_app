# テスト用のマスタを作るひな形。テストのデータベースには seed が入らないので、使うマスタはテストの中で作る。
# create(:industry) のように使う
FactoryBot.define do
  factory :industry do
    sequence(:name) { |n| "業界#{n}" }
    sequence(:position) { |n| n }
  end

  factory :business_type do
    sequence(:name) { |n| "事業形態#{n}" }
    sequence(:position) { |n| n }
  end
end
