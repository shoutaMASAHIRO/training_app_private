FROM debian:stable-slim AS builder

RUN apt-get update && apt-get install -y \
    curl git unzip bash-completion locales xz-utils libgtk-3-dev \
  && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter precache --web
RUN flutter config --enable-web

# ★ build context は fitness_app なので、プロジェクトは /app 直下に置く
COPY . /app
WORKDIR /app

# 依存関係
RUN flutter pub get

# webが無ければ生成
RUN test -d web || flutter create . --platforms web

# flutter create 後に依存が変わる場合があるので再取得
RUN flutter pub get

# ビルド（wasm dry run回避）
RUN flutter build web --release --pwa-strategy=none --no-wasm-dry-run

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html

# ★ nginx.conf も /app/nginx.conf が正しい
COPY --from=builder /app/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
