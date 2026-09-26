# テスト用の募集を作るひな形。create(:job_posting) のように使う。
# 掲載に必要な2つ（インターンですること、時給）は最初から入れておくので、
# create(:job_posting, :published) とするだけで掲載中の募集になる（その他決め事.md の 5-9）
FactoryBot.define do
  factory :job_posting do
    company_profile { create(:company_user).company_profile }
    sequence(:title) { |n| "募集#{n}" }
    status { :unpublished }
    internship_details { "Rails で API を作ります" }
    hourly_wage { 1500 }

    # 掲載中。最初に掲載した日時（published_at）は、モデルの before_save が入れる
    trait :published do
      status { :published }
    end

    # 終了。新規作成では終了を選べない（権限_バリデーション.md の 17-2-2）ので、掲載中で作ってから終了にする
    trait :closed do
      status { :published }
      after(:create) { |job_posting| job_posting.update!(status: :closed) }
    end

    # 掲載したことがある非公開。掲載中で作ってから非公開に戻す（最初に掲載した日時は残る）
    trait :unpublished_after_published do
      status { :published }
      after(:create) { |job_posting| job_posting.update!(status: :unpublished) }
    end
  end
end
