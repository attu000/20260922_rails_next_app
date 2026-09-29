Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  # API（design/designs/API設計.md の 16-1）。すべて /api/ で始まる。
  # defaults: { format: :json } で、ブラウザのアドレス欄から開いたときも JSON のテンプレートを使う
  namespace :api, defaults: { format: :json } do
    # ① POST /api/session（ログイン）、② DELETE /api/session（ログアウト）
    resource :session, only: %i[create destroy]
    # ③ GET /api/me（ログイン中の人）
    get "me", to: "me#show"
    # ⑦ GET /api/options（選択肢とマスタ）
    get "options", to: "options#show"
    # ログイン前に使う新規登録の窓口（16-3 ④⑤⑥）。企業・学生の外に置く
    # ④ POST /api/email_checks（メールアドレスの確認）
    resources :email_checks, only: :create
    # ⑤ POST /api/company_registrations（企業の新規登録）
    resources :company_registrations, only: :create
    # ⑥ POST /api/student_registrations（学生の新規登録）
    resources :student_registrations, only: :create

    # /api/company/…：企業の窓口（16-1-3）。コントローラーは app/controllers/api/company/ に置き、
    # すべて Api::Company::BaseController を親にする（学生なら 403）
    namespace :company do
      # ⑧ GET /api/company/profile（自社のプロフィール）、⑨ PATCH /api/company/profile（保存）。
      # 自社に1つしかないので、番号を付けない単数形にする（16-1-4）
      resource :profile, only: %i[show update] do
        # ⑩ POST /api/company/profile/icon（企業のアイコン）
        resource :icon, only: :create, controller: "profile_icons"
      end

      # ⑪ GET /api/company/job_postings（自社の募集の一覧）、⑫ GET /api/company/job_postings/:id（1件）、
      # ⑬ POST /api/company/job_postings（新規作成）、⑭ PATCH /api/company/job_postings/:id（保存・状態の変更）。
      # 募集は消さず、状態で管理するので、消す窓口（destroy）は作らない（16-3 ⑭）
      resources :job_postings, only: %i[index show create update]
      # ㉑ GET /api/company/candidacies（候補者一覧）、㉖ POST /api/company/candidacies/:id/match（マッチ）、
      # ㉗ …/decline（見送り）、㉘ …/undo_decline（見送りの取り消し）、㉙ …/pass（合格）、㉚ …/fail（不合格）。
      # 状態を変える操作は、1件ごとの操作（member）として、やりとりの番号の後ろに操作の名前を付ける（16-1-4）
      resources :candidacies, only: :index do
        member do
          post :match
          post :decline
          post :undo_decline
          # URL は /pass・/fail のまま、つなぐ先のメソッドの名前だけ変える。
          # fail は Ruby に最初からある命令（raise の別名）なので、同じ名前のメソッドを作らない（PR269）
          post :pass, action: :mark_passed
          post :fail, action: :mark_failed
        end
      end
      # ㉒ GET /api/company/students（学生検索）、㉓ GET /api/company/students/:id（学生詳細）
      resources :students, only: %i[index show] do
        # ㊲ GET /api/company/students/:student_id/message_thread（その学生とのチャット）、
        # ㊳ POST /api/company/students/:student_id/message_thread/messages（送信）。
        # スレッドは企業×学生で1本なので、学生の下に番号を付けない単数形で置く（16-3-7）
        resource :message_thread, only: :show do
          resources :messages, only: :create
        end
        # ㉕ GET /api/company/students/:student_id/similar_students（この学生に似た学生。順14）。
        # 学生の下にある別の一覧として、コントローラーを分ける（チャットと同じ形）
        resources :similar_students, only: :index
      end
      # ㉔ POST /api/company/scouts（スカウト）
      resources :scouts, only: :create
      # ㊱ GET /api/company/message_threads（スレッド一覧）
      resources :message_threads, only: :index
      # ㊷ GET /api/company/notifications（通知の一覧）、㊸ POST /api/company/notifications/:id/read（1件を既読にする）、
      # ㊹ POST /api/company/notifications/read_all（すべて既読にする）。順15。
      # 1件ごとの操作は member、全体への操作は collection に置く（16-1-4）
      resources :notifications, only: :index do
        post :read, on: :member
        post :read_all, on: :collection
      end
    end

    # /api/student/…：学生の窓口（16-1-3）。コントローラーは app/controllers/api/student/ に置き、
    # すべて Api::Student::BaseController を親にする（企業なら 403）
    namespace :student do
      # ⑮ GET /api/student/profile（自分のプロフィール）、⑯ PATCH /api/student/profile（保存）。
      # 自分に1つしかないので、番号を付けない単数形にする（16-1-4）
      resource :profile, only: %i[show update] do
        # ⑰ POST /api/student/profile/icon（学生のアイコン）
        resource :icon, only: :create, controller: "profile_icons"
      end

      # ⑱ GET /api/student/job_postings（募集検索）、⑲ GET /api/student/job_postings/:id（募集詳細）
      resources :job_postings, only: %i[index show] do
        # ㉝ GET /api/student/job_postings/:job_posting_id/similar_job_postings（この募集に似た募集。順14）
        resources :similar_job_postings, only: :index
      end
      # ⑳ GET /api/student/companies/:id（企業詳細）
      resources :companies, only: :show do
        # ㊵ GET /api/student/companies/:company_id/message_thread（その企業とのチャット）、
        # ㊶ POST /api/student/companies/:company_id/message_thread/messages（送信）。
        # スレッドは企業×学生で1本なので、企業の下に番号を付けない単数形で置く（16-3-7）
        resource :message_thread, only: :show do
          resources :messages, only: :create
        end
      end
      # ㉞ GET /api/student/candidacies（募集管理）、㉛ POST /api/student/candidacies（応募）、
      # ㉜ POST /api/student/candidacies/:id/match（スカウトにマッチ）
      resources :candidacies, only: %i[index create] do
        post :match, on: :member
      end
      # ㉟ GET /api/student/scouts（スカウト管理）
      resources :scouts, only: :index
      # ㊴ GET /api/student/message_threads（スレッド一覧）
      resources :message_threads, only: :index
      # ㊺ GET /api/student/job_trials（プチ職業体験の講座の一覧）、㊻ GET /api/student/job_trials/:id（講座の中身）。順18
      resources :job_trials, only: %i[index show] do
        # ㊽ PUT /api/student/job_trials/:job_trial_id/self_analysis（自己分析の保存）。
        # 自己分析は学生×講座に1件なので、講座の下に番号を付けない単数形で置く（チャットと同じ形）。
        # 作る・上書きを1つの窓口で行うので PUT にする（Rails の決まりで PATCH でも同じ処理につながる）
        resource :self_analysis, only: :update
      end
      # ㊼ POST /api/student/job_trial_hurdles/:id/check（問題の正否の判定）。
      # ハードルの番号だけで一意に決まるので、講座の番号はパスに入れない（PR386）
      resources :job_trial_hurdles, only: [] do
        post :check, on: :member
      end
    end
  end

  # /api/ の下の、ここより上のどれにも当てはまらない URL は、404 の形で返す（API設計.md の 16-1-10）。
  # 上から順に当てはめるので、この行は必ずいちばん最後に置く
  match "api/*path", to: "errors#not_found", via: :all
end
