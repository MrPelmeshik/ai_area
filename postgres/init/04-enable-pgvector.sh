#!/bin/bash
set -e

echo "Установка расширения pgvector во все базы данных..."

# Функция для установки расширения в БД
install_extension() {
    local db_name=$1
    if psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1; then
        echo "Установка расширения pgvector в базу данных $db_name..."
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
            CREATE EXTENSION IF NOT EXISTS vector;
EOSQL
        echo "Расширение pgvector установлено в базу данных $db_name"
    else
        echo "База данных $db_name не существует, пропускаем"
    fi
}

# Устанавливаем расширение в основную БД
install_extension "$POSTGRES_DB"

# Устанавливаем расширение в БД из дампов
for db in demo periodic_table happiness_index titanic netflix pagila chinook lego employees; do
    install_extension "$db"
done

echo "Установка расширения pgvector завершена"

