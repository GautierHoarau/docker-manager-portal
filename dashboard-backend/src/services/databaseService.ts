import { Pool } from 'pg';

class DatabaseService {
  private pool: Pool;
  private static instance: DatabaseService;

  constructor() {
    // Configuration flexible pour support des variables séparées ou DATABASE_URL
    let poolConfig: any;
    
    if (process.env.POSTGRES_HOST) {
      // Utilisation des variables d'environnement séparées (production Azure)
      poolConfig = {
        host: process.env.POSTGRES_HOST,
        port: parseInt(process.env.POSTGRES_PORT || '5432'),
        user: process.env.POSTGRES_USER || 'postgres',
        password: process.env.POSTGRES_PASSWORD,
        database: process.env.POSTGRES_DB || 'portail_cloud_db',
        ssl: process.env.POSTGRES_SSL === 'true' ? { rejectUnauthorized: false } : false,
        max: 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
      };
    } else {
      // Utilisation de DATABASE_URL (développement local ou fallback)
      const databaseUrl = process.env.DATABASE_URL || 
        'postgresql://postgres:postgres123@localhost:5432/portail_cloud_db';
      
      poolConfig = {
        connectionString: databaseUrl,
        ssl: false, // Pas de SSL pour le développement local
        max: 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
      };
    }
    
    this.pool = new Pool(poolConfig);

    // Tester la connexion au démarrage
    this.testConnection();
  }

  public static getInstance(): DatabaseService {
    if (!DatabaseService.instance) {
      DatabaseService.instance = new DatabaseService();
    }
    return DatabaseService.instance;
  }

  private async testConnection() {
    try {
      const client = await this.pool.connect();
      console.log('✅ PostgreSQL connection successful');
      client.release();
    } catch (error) {
      console.error('❌ PostgreSQL connection failed:', error);
      // En mode développement, on peut continuer sans BDD
      if (process.env.NODE_ENV !== 'production') {
        console.warn('⚠️  Continuing without database in development mode');
      } else {
        process.exit(1);
      }
    }
  }

  public async initializeTables() {
    try {
      console.log('🔧 Initializing database tables...');
      
      // Test de connexion d'abord
      await this.query('SELECT 1 as test');
      console.log('✅ Database connection test successful');
      
      // Création de la table users
      console.log('📋 Creating users table...');
      await this.query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          email VARCHAR(255) UNIQUE NOT NULL,
          password_hash VARCHAR(255) NOT NULL,
          role VARCHAR(50) DEFAULT 'client' CHECK (role IN ('admin', 'client')),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          is_active BOOLEAN DEFAULT true
        );
      `);
      console.log('✅ Users table created successfully');

      // Vérification des tables existantes
      const tables = await this.query(`
        SELECT table_name FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      `);
      console.log('📊 Tables found:', tables.rows);

      // Insertion d'un utilisateur admin par défaut
      console.log('👤 Creating default admin user...');
      const result = await this.query(`
        INSERT INTO users (email, password_hash, role) 
        VALUES ('admin@example.com', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
        ON CONFLICT (email) DO NOTHING
        RETURNING id;
      `);
      
      if (result.rows.length > 0) {
        console.log('✅ Admin user created with ID:', result.rows[0].id);
      } else {
        console.log('ℹ️  Admin user already exists');
      }

      // Vérification finale
      const userCount = await this.query('SELECT COUNT(*) as count FROM users');
      console.log(`📈 Total users in database: ${userCount.rows[0].count}`);
      
      console.log('🎉 Database initialization completed successfully!');
    } catch (error: any) {
      console.error('❌ Database initialization failed:', error);
      console.error('Error details:', {
        message: error.message || 'Unknown error',
        code: error.code || 'Unknown code',
        severity: error.severity || 'Unknown severity',
        detail: error.detail || 'No additional details',
        hint: error.hint || 'No hints available'
      });
      throw error;
    }
  }

  async query(text: string, params?: any[]): Promise<any> {
    const start = Date.now();
    try {
      const res = await this.pool.query(text, params);
      const duration = Date.now() - start;
      console.log('Executed query', { text, duration, rows: res.rowCount });
      return res;
    } catch (error) {
      console.error('Database query error:', error);
      throw error;
    }
  }

  async getClient() {
    return await this.pool.connect();
  }

  async close() {
    await this.pool.end();
  }

  // Méthodes utilitaires pour les requêtes communes
  async findOne(table: string, conditions: Record<string, any>): Promise<any> {
    const whereClause = Object.keys(conditions).map((key, index) => `${key} = $${index + 1}`).join(' AND ');
    const values = Object.values(conditions);
    
    const result = await this.query(
      `SELECT * FROM ${table} WHERE ${whereClause} LIMIT 1`,
      values
    );
    
    return result.rows[0] || null;
  }

  async findMany(table: string, conditions?: Record<string, any>, limit?: number): Promise<any[]> {
    let query = `SELECT * FROM ${table}`;
    let values: any[] = [];

    if (conditions && Object.keys(conditions).length > 0) {
      const whereClause = Object.keys(conditions).map((key, index) => `${key} = $${index + 1}`).join(' AND ');
      query += ` WHERE ${whereClause}`;
      values = Object.values(conditions);
    }

    if (limit) {
      query += ` LIMIT ${limit}`;
    }

    const result = await this.query(query, values);
    return result.rows;
  }

  async insert(table: string, data: Record<string, any>): Promise<any> {
    const columns = Object.keys(data).join(', ');
    const placeholders = Object.keys(data).map((_, index) => `$${index + 1}`).join(', ');
    const values = Object.values(data);

    const result = await this.query(
      `INSERT INTO ${table} (${columns}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return result.rows[0];
  }

  async update(table: string, id: number, data: Record<string, any>): Promise<any> {
    const setClause = Object.keys(data).map((key, index) => `${key} = $${index + 2}`).join(', ');
    const values = [id, ...Object.values(data)];

    const result = await this.query(
      `UPDATE ${table} SET ${setClause} WHERE id = $1 RETURNING *`,
      values
    );

    return result.rows[0];
  }

  async delete(table: string, id: number): Promise<boolean> {
    const result = await this.query(`DELETE FROM ${table} WHERE id = $1`, [id]);
    return result.rowCount > 0;
  }

  // Méthodes spécifiques aux logs d'activité
  async logActivity(userId: number, clientId: number | null, action: string, details?: any, ipAddress?: string) {
    return await this.insert('activity_logs', {
      user_id: userId,
      client_id: clientId,
      action,
      details: details ? JSON.stringify(details) : null,
      ip_address: ipAddress
    });
  }
}

export default DatabaseService;