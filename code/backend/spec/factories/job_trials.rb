# テスト用のプチ職業体験（講座・ハードル・自己分析）を作るひな形。
# 本物の講座は db/job_trials/ の YAML から読み込むが、テストのデータベースには入らないので、テストの中で作る
FactoryBot.define do
  factory :job_trial do
    job_middle_category
    sequence(:code) { |n| "trial-#{n}" }
    sequence(:title) { |n| "講座#{n}" }
    intro { "はじめに" }
    sequence(:position) { |n| n }

    # ハードルを4つ付けた講座。create(:job_trial, :with_hurdles) のように使う
    trait :with_hurdles do
      after(:create) do |job_trial|
        4.times { |i| create(:job_trial_hurdle, job_trial: job_trial, position: i + 1) }
      end
    end
  end

  factory :job_trial_hurdle do
    job_trial
    sequence(:code) { |n| "hurdle-#{n}" }
    sequence(:position) { |n| n }
    sequence(:name) { |n| "ハードル#{n}" }
    overview { "概要" }
    difficulty { "難しさ" }
    tips { "コツ" }
    example { "具体例" }
    goal { "ゴール" }
    question { "問題" }
    choices do
      [
        { "key" => "A", "body" => "選択肢A", "correct" => true, "explanation" => "Aの解説" },
        { "key" => "B", "body" => "選択肢B", "correct" => false, "explanation" => "Bの解説" }
      ]
    end
  end

  # 自己分析。講座（ハードル4つ付き）と学生も一緒に作り、得意は1つ目、伸ばしたいのは4つ目のハードルにする
  factory :self_analysis do
    job_trial { create(:job_trial, :with_hurdles) }
    student_profile { create(:student_user).student_profile }
    strength_hurdle { job_trial.hurdles.first }
    growth_hurdle { job_trial.hurdles.last }
    strength_reason { "得意だと感じた理由" }
    growth_reason { :curiosity }
    growth_detail { "楽しさを感じた部分" }
    next_step { "次にやってみたいこと" }
  end
end
