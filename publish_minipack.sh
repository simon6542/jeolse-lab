#!/usr/bin/env bash
# 미니팩 랜딩 배포 — 리틀리 상품 URL이 나온 뒤에 1회 실행.
# 사용: ./publish_minipack.sh "https://litt.ly/....."
#
# 왜 두 단계인가: URL 없이 배포하면 구매 버튼이 죽은 링크로 라이브에 나간다.
# 그래서 minipack.html은 {{LITTLY_URL}} 플레이스홀더 상태로 커밋하지 않고 두었다가,
# URL이 생긴 시점에 이 스크립트가 치환 → 사이트맵 등록 → 푸시까지 한 번에 한다.
set -euo pipefail
cd "$(dirname "$0")"

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "사용법: ./publish_minipack.sh \"<리틀리 상품 URL>\""; exit 1
fi
case "$URL" in
  https://*litt.ly/*|https://litt.ly/*) ;;
  *) echo "❌ 리틀리 URL이 아닌 것 같습니다: $URL"; exit 1 ;;
esac

if ! grep -q '{{LITTLY_URL}}' minipack.html; then
  echo "⚠️  플레이스홀더가 이미 치환돼 있습니다. 현재 구매 링크:"
  grep -o 'href="[^"]*litt[^"]*"' minipack.html || true
  echo "   다시 바꾸려면 minipack.html의 구매 버튼 href를 직접 수정하세요."; exit 1
fi

# 1) 구매 링크 치환
python3 - "$URL" <<'PY'
import io, sys
url = sys.argv[1]
p = "minipack.html"
s = io.open(p, encoding="utf-8").read()
assert "{{LITTLY_URL}}" in s
io.open(p, "w", encoding="utf-8").write(s.replace("{{LITTLY_URL}}", url))
print("✅ 구매 링크 치환:", url)
PY

# 2) 사이트맵 등록 (자연 검색 유입 = 잠식 없는 순증 경로라 색인시킨다)
python3 - <<'PY'
import io, datetime
p = "sitemap.xml"
s = io.open(p, encoding="utf-8").read()
if "minipack.html" in s:
    print("• 사이트맵에 이미 있음 — 건너뜀")
else:
    today = datetime.date.today().isoformat()
    entry = ('  <url><loc>https://howmuchlab.com/jeolse-lab/minipack.html</loc>'
             '<lastmod>%s</lastmod><priority>0.9</priority></url>\n' % today)
    s = s.replace("</urlset>", entry + "</urlset>")
    io.open(p, "w", encoding="utf-8").write(s)
    print("✅ 사이트맵 등록")
PY

# 3) 배포
git add minipack.html sitemap.xml
git commit -m "절세랩: 양도세 미니팩 랜딩 공개 (9,900원, 리틀리 연결)"
git push

echo
echo "다음: 라이브 확인 → https://howmuchlab.com/jeolse-lab/minipack.html"
echo "     구글 서치콘솔에서 위 URL 색인 요청 1회 (SY)"
