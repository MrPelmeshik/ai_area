#!/bin/bash
set -e

# Проверка наличия переменных окружения
if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_DB" ]; then
    echo "Ошибка: переменные окружения POSTGRES_USER, POSTGRES_PASSWORD и POSTGRES_DB должны быть установлены"
    exit 1
fi

# Проверка наличия переменных для пользователей n8n и flowise
if [ -z "$N8N_DB_POSTGRES_USER" ] || [ -z "$FLOWISE_DB_USER" ]; then
    echo "Предупреждение: переменные N8N_DB_POSTGRES_USER или FLOWISE_DB_USER не установлены, права не будут предоставлены"
fi

# Переход в директорию с дампами
DUMP_DIR="/dumps"
if [ ! -d "$DUMP_DIR" ]; then
    echo "Ошибка: директория $DUMP_DIR не найдена"
    exit 1
fi

cd "$DUMP_DIR"

# Функция для создания базы данных, если она не существует
create_database_if_not_exists() {
    local db_name=$1
    echo "Проверка существования базы данных: $db_name"
    if ! psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1; then
        echo "Создание базы данных $db_name..."
        psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE DATABASE $db_name;"
    else
        echo "База данных $db_name уже существует"
    fi
}

# Функция для создания схемы, если она не существует
create_schema_if_not_exists() {
    local db_name=$1
    local schema_name=$2
    echo "Проверка существования схемы $schema_name в базе данных $db_name"
    if ! psql -U "$POSTGRES_USER" -d "$db_name" -tc "SELECT 1 FROM pg_namespace WHERE nspname = '$schema_name'" | grep -q 1; then
        echo "Создание схемы $schema_name в базе данных $db_name..."
        psql -U "$POSTGRES_USER" -d "$db_name" -c "CREATE SCHEMA $schema_name;"
    else
        echo "Схема $schema_name уже существует в базе данных $db_name"
    fi
}

# Функция для предоставления прав пользователям n8n и flowise на базу данных
grant_permissions_to_users() {
    local db_name=$1
    local schema_name="${2:-public}"
    
    if [ -n "$N8N_DB_POSTGRES_USER" ] && [ -n "$FLOWISE_DB_USER" ]; then
        echo "Предоставление прав пользователям ${N8N_DB_POSTGRES_USER} и ${FLOWISE_DB_USER} на базу данных $db_name (схема $schema_name)..."
        psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$db_name" <<-EOSQL
            -- Права на базу данных
            GRANT CONNECT ON DATABASE "$db_name" TO "${N8N_DB_POSTGRES_USER}";
            GRANT CONNECT ON DATABASE "$db_name" TO "${FLOWISE_DB_USER}";
            
            -- Права на схему
            GRANT USAGE ON SCHEMA "$schema_name" TO "${N8N_DB_POSTGRES_USER}";
            GRANT USAGE ON SCHEMA "$schema_name" TO "${FLOWISE_DB_USER}";
            GRANT ALL ON SCHEMA "$schema_name" TO "${N8N_DB_POSTGRES_USER}";
            GRANT ALL ON SCHEMA "$schema_name" TO "${FLOWISE_DB_USER}";
            
            -- Права на все существующие таблицы
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA "$schema_name" TO "${N8N_DB_POSTGRES_USER}";
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA "$schema_name" TO "${FLOWISE_DB_USER}";
            
            -- Права на все существующие последовательности
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA "$schema_name" TO "${N8N_DB_POSTGRES_USER}";
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA "$schema_name" TO "${FLOWISE_DB_USER}";
            
            -- Права на все существующие функции
            GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA "$schema_name" TO "${N8N_DB_POSTGRES_USER}";
            GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA "$schema_name" TO "${FLOWISE_DB_USER}";
            
            -- Права по умолчанию для будущих объектов
            ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema_name" GRANT ALL ON TABLES TO "${N8N_DB_POSTGRES_USER}";
            ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema_name" GRANT ALL ON TABLES TO "${FLOWISE_DB_USER}";
            ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema_name" GRANT ALL ON SEQUENCES TO "${N8N_DB_POSTGRES_USER}";
            ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema_name" GRANT ALL ON SEQUENCES TO "${FLOWISE_DB_USER}";
            ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema_name" GRANT ALL ON FUNCTIONS TO "${N8N_DB_POSTGRES_USER}";
            ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema_name" GRANT ALL ON FUNCTIONS TO "${FLOWISE_DB_USER}";
EOSQL
    fi
}

# Функция для скачивания файла, если он отсутствует
download_file_if_not_exists() {
    local file_name=$1
    local url=$2
    
    if [ ! -f "$file_name" ]; then
        echo "Файл $file_name не найден. Попытка скачать с $url..."
        
        # Пытаемся использовать wget, если доступен
        if command -v wget >/dev/null 2>&1; then
            if wget -q --show-progress -O "$file_name" "$url"; then
                echo "Файл $file_name успешно скачан"
                return 0
            else
                echo "Ошибка: не удалось скачать $file_name с помощью wget"
                return 1
            fi
        # Иначе используем curl
        elif command -v curl >/dev/null 2>&1; then
            if curl -L -o "$file_name" "$url"; then
                echo "Файл $file_name успешно скачан"
                return 0
            else
                echo "Ошибка: не удалось скачать $file_name с помощью curl"
                return 1
            fi
        else
            echo "Ошибка: wget и curl не найдены. Невозможно скачать $file_name"
            return 1
        fi
    else
        echo "Файл $file_name уже существует"
        return 0
    fi
}

# Загрузка demo дампа
DEMO_FILE="demo-20250901-1y.sql.gz"
DEMO_URL="https://edu.postgrespro.ru/demo-20250901-1y.sql.gz"

if download_file_if_not_exists "$DEMO_FILE" "$DEMO_URL"; then
    if [ -f "$DEMO_FILE" ]; then
        echo "Загрузка $DEMO_FILE в базу данных..."
        gunzip -c "$DEMO_FILE" | psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
        # Предоставляем права на схему public в основной базе данных
        grant_permissions_to_users "$POSTGRES_DB" "public"
    fi
else
    echo "Предупреждение: пропускаем загрузку demo дампа из-за ошибки скачивания"
fi

# Обработка файлов из postgres-sample-dbs
SAMPLE_DBS_DIR="postgres-sample-dbs"
if [ -d "$SAMPLE_DBS_DIR" ]; then
    cd "$SAMPLE_DBS_DIR"
    
    # Создание и загрузка periodic_table
    if [ -f "periodic_table.sql" ]; then
        create_database_if_not_exists "periodic_table"
        echo "Загрузка periodic_table.sql..."
        psql -U "$POSTGRES_USER" -d periodic_table -f periodic_table.sql
        grant_permissions_to_users "periodic_table" "public"
    fi
    
    # Создание и загрузка happiness_index
    if [ -f "happiness_index.sql" ]; then
        create_database_if_not_exists "happiness_index"
        echo "Загрузка happiness_index.sql..."
        psql -U "$POSTGRES_USER" -d happiness_index -f happiness_index.sql
        grant_permissions_to_users "happiness_index" "public"
    fi
    
    # Создание и загрузка titanic
    if [ -f "titanic.sql" ]; then
        create_database_if_not_exists "titanic"
        echo "Загрузка titanic.sql..."
        psql -U "$POSTGRES_USER" -d titanic -f titanic.sql
        grant_permissions_to_users "titanic" "public"
    fi
    
    # Создание и загрузка netflix
    if [ -f "netflix.sql" ]; then
        create_database_if_not_exists "netflix"
        echo "Загрузка netflix.sql..."
        psql -U "$POSTGRES_USER" -d netflix -f netflix.sql
        grant_permissions_to_users "netflix" "public"
    fi
    
    # Создание и загрузка pagila
    if [ -f "pagila.sql" ]; then
        create_database_if_not_exists "pagila"
        echo "Загрузка pagila.sql..."
        psql -U "$POSTGRES_USER" -d pagila -f pagila.sql
        grant_permissions_to_users "pagila" "public"
    fi
    
    # Создание и загрузка chinook
    if [ -f "chinook.sql" ]; then
        create_database_if_not_exists "chinook"
        echo "Загрузка chinook.sql..."
        psql -U "$POSTGRES_USER" -d chinook -f chinook.sql
        grant_permissions_to_users "chinook" "public"
    fi
    
    # Создание и загрузка lego
    if [ -f "lego.sql" ]; then
        create_database_if_not_exists "lego"
        echo "Загрузка lego.sql..."
        psql -U "$POSTGRES_USER" -d lego -f lego.sql
        grant_permissions_to_users "lego" "public"
    fi
    
    # Создание и загрузка employees
    if [ -f "employees.sql.gz" ]; then
        create_database_if_not_exists "employees"
        create_schema_if_not_exists "employees" "employees"
        echo "Загрузка employees.sql.gz..."
        gunzip -c employees.sql.gz | psql -U "$POSTGRES_USER" -d employees
        grant_permissions_to_users "employees" "employees"
    fi
    
    cd ..
fi

echo "Все дампы успешно загружены!"