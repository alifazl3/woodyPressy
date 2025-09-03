# 🐳 WordPress + MySQL + phpMyAdmin Docker Setup

This project sets up a local development environment using **Docker Compose** that includes:

- ✅ WordPress (latest)
- ✅ MySQL 5.7 with persistent storage
- ✅ phpMyAdmin for database management
- ✅ Isolated Docker network
- ✅ Mounted volumes for data persistence
- ✅ Environment variable support via `.env` file

---

## 📁 Project Structure

```
project-root/
├── docker-compose.yml
├── .env
├── .gitignore
├── wordpress/        # Mounted WordPress content
└── mysql/            # MySQL database files
```
---

## ⚙️ Requirements

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)

---

## 📦 Environment Variables

All credentials and database settings are stored in the `.env` file:

```env
MYSQL_ROOT_PASSWORD=yourRootPassword
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=wordpress

WORDPRESS_DB_HOST=db
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=wordpress
```

## 🚀 Quick Start

Spin up a fresh WordPress stack with random ports:

```bash
./new-wordpress.sh apple-silicon/docker-compose.yml
```

Each run creates a new project name so you always get a clean WordPress instance and it prints the ports for WordPress, MySQL, and phpMyAdmin.
