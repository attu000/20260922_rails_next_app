# テスト用のやりとりを作るひな形。create(:candidacy) で「掲載中の募集への応募（未マッチ）」になる。
# create(:candidacy, :scout) でスカウト由来、create(:candidacy, status: :matched) のように状態も変えられる
FactoryBot.define do
  factory :candidacy do
    job_posting { create(:job_posting, :published) }
    student_profile { create(:student_user).student_profile }
    origin { :application }
    status { :unmatched }

    # スカウト由来
    trait :scout do
      origin { :scout }
    end
  end
end
