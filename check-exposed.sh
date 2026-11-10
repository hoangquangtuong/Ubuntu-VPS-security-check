#!/usr/bin/env bash
# Kiểm tra website của BẠN có để lộ file quan trọng không.
# Chạy:  bash check-exposed.sh                      (mặc định: https://ten-mien.com và /example)
#        bash check-exposed.sh https://ten-mien.com  (tự chọn địa chỉ)
if [ $# -gt 0 ]; then
  BASES=("$@")
else
  BASES=("https://ten-mien.com" "https://ten-mien.com/example")
fi

PATHS=(
  .env .env.local .env.production .env.development
  .git/config .git/HEAD .gitignore
  package.json package-lock.json yarn.lock
  next.config.js tsconfig.json
  server.js app.js index.js ecosystem.config.js
  .next/BUILD_ID
  backup.zip backup.tar.gz backup.sql db.sql dump.sql database.sql
  config.json config.js users.json db.json
  .DS_Store .htpasswd .bash_history id_rsa .ssh/authorized_keys
  phpinfo.php info.php wp-config.php server-status
)

for base in "${BASES[@]}"; do
  base="${base%/}"
  rnd="khong-ton-tai-$RANDOM$RANDOM"
  read -r bcode bsize < <(curl -s -o /dev/null -w '%{http_code} %{size_download}' -m 15 "$base/$rnd")
  echo
  echo "== $base   (đường dẫn không tồn tại trả về: HTTP $bcode, $bsize byte)"
  found=0
  for p in "${PATHS[@]}"; do
    read -r code size < <(curl -s -o /dev/null -w '%{http_code} %{size_download}' -m 15 "$base/$p")
    # chỉ báo khi trả về 200 và khác với trang "không tồn tại" của chính web đó
    if [ "$code" = "200" ] && ! { [ "$bcode" = "200" ] && [ "$size" = "$bsize" ]; }; then
      echo "   [CÓ THỂ BỊ LỘ] $base/$p   (HTTP $code, $size byte)"
      found=1
    fi
    sleep 0.2
  done
  [ "$found" = 0 ] && echo "   Không thấy file nhạy cảm nào trả về 200."
done