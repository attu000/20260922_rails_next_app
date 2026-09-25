# 「番号の一覧が、重複なく、すべてマスタにあるか」の確認を、ここ1か所にまとめる（design/designs/技術構成.md の 9-2）。
# 企業プロフィール（業界・事業形態）、募集（職種・使用技術など）、学生プロフィールで使い回す。
# Django でいえば、同じバリデーション関数を validators.py に切り出して、複数のモデルから使うのにあたる。
#
# Rails に任せると、存在しない番号は「見つからない」（404）になるが、入力の誤りなので 422 で返す（権限_バリデーション.md の 17-3-4）
module MasterIdsValidation
  extend ActiveSupport::Concern

  private

  # 送られていなければ（nil）何もしない。誤りは errors に入れる（文言は config/locales/ja.yml の errors.messages）
  def validate_master_ids(attribute, ids, master)
    return if ids.nil?

    ids = Array(ids).map(&:to_s)
    errors.add(attribute, :duplicated) if ids.uniq.size != ids.size
    errors.add(attribute, :not_selectable) if master.where(id: ids.uniq).count != ids.uniq.size
  end

  # 番号1つがマスタにあるか（募集の勤務地、学生の大学・学部・学科・在住の都道府県、プログラミング歴の技術）。
  # 空欄なら何もしない。ないまま保存すると、データベースの外部キーで弾かれてエラーの画面（500）になるため、手前で止める。
  # 文言は「勤務地は一覧にありません」の形（rails-i18n の inclusion）
  def validate_master_id(attribute, id, master)
    errors.add(attribute, :inclusion) if id.present? && !master.exists?(id)
  end
end
