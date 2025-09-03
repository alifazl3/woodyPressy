#!/bin/bash

# تابع برای بررسی آزاد بودن پورت
check_port() {
  local port=$1
  if command -v ss >/dev/null 2>&1; then
    ss -tuln | grep -q ":${port}\s" && return 1
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln | grep -q ":${port}\s" && return 1
  else
    echo "Error: Neither ss nor netstat is available to check ports."
    exit 1
  fi
  return 0
}

# تولید پورت تصادفی و بررسی آزاد بودن آن
generate_free_port() {
  local range_start=$1
  local range_end=$2
  local port
  while true; do
    port=$((RANDOM % (range_end - range_start + 1) + range_start))
    if check_port $port; then
      echo $port
      return
    fi
  done
}

# تابع برای توقف سرویس‌ها
cleanup() {
  echo "Stopping Docker Compose services..."
  docker-compose down
  echo "Services stopped and cleaned up."
}

# ثبت تابع cleanup برای اجرا در هنگام توقف اسکریپت
trap cleanup SIGINT SIGTERM

# تولید یک نام منحصربه‌فرد برای نمونه
INSTANCE_NAME="wp_instance_$(date +%s)"

# تولید پورت‌های تصادفی
PORT_WP=$(generate_free_port 8000 8999)
PORT_PMA=$(generate_free_port 9000 9999)

# تولید رمزهای تصادفی برای امنیت بیشتر
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
MYSQL_PASSWORD=$(openssl rand -base64 12)

# ایجاد یا به‌روزرسانی فایل .env
cat > .env << EOL
INSTANCE_NAME=${INSTANCE_NAME}
PORT_WP=${PORT_WP}
PORT_PMA=${PORT_PMA}
WORDPRESS_DB_HOST=db
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=${MYSQL_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=${MYSQL_PASSWORD}
EOL

# ایجاد دایرکتوری برای داده‌ها
mkdir -p "${INSTANCE_NAME}/wordpress"
mkdir -p "${INSTANCE_NAME}/mysql"
touch "${INSTANCE_NAME}/php.ini"

# ایجاد صفحه HTML
cat > "${INSTANCE_NAME}/index.html" << EOL
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WordPress Instance: ${INSTANCE_NAME}</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background-color: #f4f4f4; }
    h1 { color: #333; }
    ul { list-style-type: none; padding: 0; }
    li { margin: 15px 0; font-size: 1.1em; }
    a { color: #007bff; text-decoration: none; }
    a:hover { text-decoration: underline; }
    pre { background: #fff; padding: 15px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .container { max-width: 800px; margin: auto; }
  </style>
</head>
<body>
  <div class="container">
    <h1>WordPress Instance: ${INSTANCE_NAME}</h1>
    <h2>Service URLs</h2>
    <ul>
      <li><strong>WordPress:</strong> <a href="http://localhost:${PORT_WP}" target="_blank">http://localhost:${PORT_WP}</a></li>
      <li><strong>phpMyAdmin:</strong> <a href="http://localhost:${PORT_PMA}" target="_blank">http://localhost:${PORT_PMA}</a></li>
    </ul>
    <h2>Database Credentials</h2>
    <pre>
Database Host: db
Database Name: wordpress
Database User: wordpress
Database Password: ${MYSQL_PASSWORD}
Root Password: ${MYSQL_ROOT_PASSWORD}
    </pre>
    <p><strong>Note:</strong> Keep these credentials secure and do not share publicly.</p>
  </div>
</body>
</html>
EOL

# راه‌اندازی سرویس‌ها
docker-compose up -d

# چاپ پورت‌ها و اطلاعات
echo "=== Service Information ==="
echo "Instance Name: ${INSTANCE_NAME}"
echo "WordPress: http://localhost:${PORT_WP}"
echo "phpMyAdmin: http://localhost:${PORT_PMA}"
echo "HTML Page: file://$(pwd)/${INSTANCE_NAME}/index.html"
echo "Database Credentials:"
echo "  Host: db"
echo "  Name: wordpress"
echo "  User: wordpress"
echo "  Password: ${MYSQL_PASSWORD}"
echo "  Root Password: ${MYSQL_ROOT_PASSWORD}"
echo "========================="

# نگه‌داشتن اسکریپت در حال اجرا تا دریافت سیگنال توقف
while true; do
  sleep 1
done