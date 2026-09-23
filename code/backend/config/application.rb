require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    # 日本時間で動かす。データベースには世界標準時（UTC）で保存し、読み書きのときに日本時間に直す。
    # Django の TIME_ZONE = 'Asia/Tokyo'、USE_TZ = True と同じ（design/designs/API設計.md の 16-1-12）
    config.time_zone = "Tokyo"

    # 日本語で動かす。Django の LANGUAGE_CODE = 'ja' にあたる。
    # 標準メッセージは rails-i18n、この API 独自の文言は config/locales/ja.yml（権限_バリデーション.md の 17-3-6）
    config.i18n.default_locale = :ja
    config.i18n.available_locales = [ :ja ]

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # API モードで外れる Cookie とセッションを戻す（技術構成.md の 3-1 A-2 の注意点1）。
    # Django の MIDDLEWARE に SessionMiddleware を入れるのと同じ。書き方は Rails 公式ガイドの API 専用アプリの章のとおり。
    # セッションは、CSRF の合言葉の「正解」を Rails 側で覚えておくために使う（画面のプログラムからは読めない）
    config.session_store :cookie_store, key: "_backend_session", same_site: :lax, secure: Rails.env.production?
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options
  end
end
