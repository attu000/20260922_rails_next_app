# 「今の状態ではできない」ことを表すエラー（design/designs/API設計.md の 16-1-10 の 409）。
# 例：応募済みの募集への応募、掲載中でない募集への応募、スカウトに企業がマッチしようとした（権限_バリデーション.md の 17-2-1）。
#
# モデルの処理（Candidacy.apply など）がこれを投げ、app/controllers/concerns/error_responses.rb が1か所で 409 の返事に変える。
# 見つからないときの 404（ActiveRecord::RecordNotFound）と同じ仕組みで、窓口ごとに 409 の分かれ道を書かずに済む（PR205）。
# Django でいうと、DRF で status_code = 409 の APIException を作って raise するのにあたる
class ConflictError < StandardError
end
