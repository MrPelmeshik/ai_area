#!/bin/bash
set -e

# Проверяем, существует ли пользователь Flowise, создаём если его нет
USER_EXISTS=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$(echo "${FLOWISE_DB_USER}" | sed "s/'/''/g")'")

if [ -z "$USER_EXISTS" ]; then
    echo "Создание пользователя ${FLOWISE_DB_USER}..."
    # Используем правильное экранирование пароля через DO блок
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
            EXECUTE format('CREATE USER %I WITH PASSWORD %L', '${FLOWISE_DB_USER}', '${FLOWISE_DB_PASSWORD}');
        END
        \$\$;
EOSQL
else
    echo "Пользователь ${FLOWISE_DB_USER} уже существует"
fi

# Проверяем, существует ли база данных Flowise, создаём если её нет
DB_EXISTS=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='$(echo "${FLOWISE_DB_NAME}" | sed "s/'/''/g")'")

if [ -z "$DB_EXISTS" ]; then
    echo "Создание базы данных ${FLOWISE_DB_NAME}..."
    # Создаём базу данных используя общую учётную запись
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE "${FLOWISE_DB_NAME}";
EOSQL
fi

# Предоставляем все привилегии пользователю Flowise на его базу данных
echo "Предоставление привилегий пользователю ${FLOWISE_DB_USER} на базу данных ${FLOWISE_DB_NAME}..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${FLOWISE_DB_NAME}" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE "${FLOWISE_DB_NAME}" TO "${FLOWISE_DB_USER}";
    GRANT ALL ON SCHEMA public TO "${FLOWISE_DB_USER}";
    ALTER SCHEMA public OWNER TO "${FLOWISE_DB_USER}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "${FLOWISE_DB_USER}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${FLOWISE_DB_USER}";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO "${FLOWISE_DB_USER}";
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

echo "База данных ${FLOWISE_DB_NAME} инициализирована"

