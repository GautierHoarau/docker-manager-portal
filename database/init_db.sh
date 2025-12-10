#!/bin/bash
# Script d'initialisation de la base de données
# Utilisable en dev et prod avec la même logique

set -e

echo "=== Initialisation Base de Données ==="

# Variables
DB_HOST=${DB_HOST:-"localhost"}
DB_PORT=${DB_PORT:-"5432"}
DB_NAME=${DB_NAME:-"portail_cloud_db"}
DB_USER=${DB_USER:-"postgres"}
DB_PASSWORD=${DB_PASSWORD}

if [ -z "$DB_PASSWORD" ]; then
    echo "Erreur: DB_PASSWORD requis"
    exit 1
fi

echo "Connexion à: $DB_HOST:$DB_PORT/$DB_NAME"

# Fonction pour exécuter SQL
execute_sql() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$1"
}

# Fonction pour exécuter un fichier SQL
execute_sql_file() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$1"
}

# Test de connexion
echo "Test de connexion..."
if ! execute_sql "SELECT 1;" > /dev/null 2>&1; then
    echo "Erreur: Impossible de se connecter à la base de données"
    exit 1
fi

echo "✓ Connexion réussie"

# Création des tables si elles n'existent pas
echo "Création des tables..."
execute_sql "
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'client' CHECK (role IN ('admin', 'client')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    docker_container_id VARCHAR(255),
    docker_image VARCHAR(255),
    status VARCHAR(50) DEFAULT 'inactive',
    port_mappings JSONB,
    environment_vars JSONB,
    resource_limits JSONB,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS activity_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    client_id INTEGER REFERENCES clients(id),
    action VARCHAR(100) NOT NULL,
    details JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_clients_name ON clients(name);
CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp);
"

echo "✓ Tables créées"

# Seed des utilisateurs de test
echo "Insertion des utilisateurs de test..."
execute_sql "
INSERT INTO users (email, password_hash, role) VALUES 
    ('admin@portail-cloud.com', '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/lewfBmdJ6Ne0W6NPq', 'admin'),
    ('client1@portail-cloud.com', '\$2b\$12\$17AY7lPOLzOrycJIjZi3yeU0WFyciKm5uKMW.o9bSc1M5JRN6aybC', 'client'),
    ('client2@portail-cloud.com', '\$2b\$12\$17AY7lPOLzOrycJIjZi3yeU0WFyciKm5uKMW.o9bSc1M5JRN6aybC', 'client'),
    ('client3@portail-cloud.com', '\$2b\$12\$17AY7lPOLzOrycJIjZi3yeU0WFyciKm5uKMW.o9bSc1M5JRN6aybC', 'client')
ON CONFLICT (email) DO NOTHING;
"

echo "✓ Utilisateurs de test créés"

# Vérification
user_count=$(execute_sql "SELECT COUNT(*) FROM users;" | grep -E '^[0-9]+$')
echo "✓ Nombre d'utilisateurs: $user_count"

echo "=== Initialisation terminée avec succès ==="