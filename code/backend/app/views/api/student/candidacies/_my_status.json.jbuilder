# 学生から見た、募集とのやりとりの状態（形E。design/designs/API設計.md の 16-3-2）。
# ⑲ 募集詳細と、㉛ 応募・㉜ マッチの返事で使う。
# candidacy：その募集との自分のやりとり。なければ nil

# none（関係なし）／applied（応募済み）／scouted（スカウトあり）／matched（マッチ済み）。計算は Candidacy#my_status
json.my_status candidacy&.my_status || "none"
json.my_candidacy_id candidacy&.id
