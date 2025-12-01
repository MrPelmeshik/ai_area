#!/bin/bash
set -e

# Используем переменную окружения N8N_DB_POSTGRES_DATABASE, если доступна, иначе по умолчанию 'n8n'
DB_NAME="${N8N_DB_POSTGRES_DATABASE:-n8n}"

# Проверяем, существует ли пользователь n8n, создаём если его нет
USER_EXISTS=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$(echo "${N8N_DB_POSTGRES_USER}" | sed "s/'/''/g")'")

if [ -z "$USER_EXISTS" ]; then
    echo "Создание пользователя ${N8N_DB_POSTGRES_USER}..."
    # Используем правильное экранирование пароля через DO блок
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
            EXECUTE format('CREATE USER %I WITH PASSWORD %L', '${N8N_DB_POSTGRES_USER}', '${N8N_DB_POSTGRES_PASSWORD}');
        END
        \$\$;
EOSQL
else
    echo "Пользователь ${N8N_DB_POSTGRES_USER} уже существует"
fi

# Проверяем, существует ли база данных n8n, создаём если её нет
DB_EXISTS=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='$(echo "$DB_NAME" | sed "s/'/''/g")'")

if [ -z "$DB_EXISTS" ]; then
    echo "Создание базы данных ${DB_NAME}..."
    # Создаём базу данных используя общую учётную запись
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE "${DB_NAME}";
EOSQL
fi

# Предоставляем все привилегии пользователю n8n на его базу данных
echo "Предоставление привилегий пользователю ${N8N_DB_POSTGRES_USER} на базу данных ${DB_NAME}..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE "${DB_NAME}" TO "${N8N_DB_POSTGRES_USER}";
    GRANT ALL ON SCHEMA public TO "${N8N_DB_POSTGRES_USER}";
    ALTER SCHEMA public OWNER TO "${N8N_DB_POSTGRES_USER}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "${N8N_DB_POSTGRES_USER}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${N8N_DB_POSTGRES_USER}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO "${N8N_DB_POSTGRES_USER}";
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

echo "База данных ${DB_NAME} инициализирована"

