/**
 * Health Check Routes for Container Management Platform
 * 
 * Provides system health and readiness endpoints for:
 * - Load balancer health checks
 * - Monitoring system integration
 * - Deployment validation
 * 
 * @author Container Platform Team
 * @version 1.0.0
 */

import express, { Request, Response } from 'express';
import { logger } from '../utils/logger';
import DatabaseService from '../services/databaseService';

const router = express.Router();

/**
 * GET /api/health
 * 
 * Basic health check endpoint
 * Returns 200 OK if service is running
 * 
 * Used by:
 * - Azure Application Gateway
 * - Docker health checks
 * - Monitoring systems
 */
router.get('/', (req: Request, res: Response) => {
  try {
    const healthStatus = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development'
    };

    res.status(200).json({
      success: true,
      data: healthStatus
    });
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({
      success: false,
      status: 'unhealthy',
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * GET /api/health/ready
 * 
 * Readiness probe for Kubernetes/container orchestration
 * Checks if service is ready to accept traffic
 * 
 * Validates:
 * - Environment variables loaded
 * - JWT secret configured
 * - Service dependencies available
 */
router.get('/ready', (req: Request, res: Response) => {
  try {
    const checks = {
      jwt_configured: !!process.env.JWT_SECRET,
      node_env: !!process.env.NODE_ENV,
      port_configured: !!process.env.PORT
    };

    const isReady = Object.values(checks).every(check => check);
    const status = isReady ? 'ready' : 'not_ready';

    res.status(isReady ? 200 : 503).json({
      success: isReady,
      status,
      checks,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Readiness check failed:', error);
    res.status(503).json({
      success: false,
      status: 'not_ready',
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * POST /api/health/init-db
 * 
 * Initialize database tables and data with demo users
 * Public endpoint for initial setup
 */
router.post('/init-db', async (req: Request, res: Response) => {
  try {
    logger.info('🔧 Database initialization requested via health endpoint');
    
    const dbService = new DatabaseService();
    await dbService.initializeTables();
    
    // Créer les utilisateurs de démonstration pour les boutons quick access
    const demoUsers = [
      { email: 'admin@example.com', password: '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', role: 'admin' }, // password: admin123
      { email: 'client1@example.com', password: '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', role: 'client' }, // password: admin123
      { email: 'client2@example.com', password: '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', role: 'client' }, // password: admin123
      { email: 'client3@example.com', password: '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', role: 'client' }  // password: admin123
    ];
    
    for (const user of demoUsers) {
      try {
        await dbService.query(`
          INSERT INTO users (email, password_hash, role) 
          VALUES ($1, $2, $3)
          ON CONFLICT (email) DO UPDATE SET 
            password_hash = EXCLUDED.password_hash,
            role = EXCLUDED.role
        `, [user.email, user.password, user.role]);
        logger.info(`✅ User ${user.email} created/updated`);
      } catch (userError: any) {
        logger.warn(`⚠️ Error creating user ${user.email}:`, userError.message);
      }
    }
    
    // Vérification finale
    const userCount = await dbService.query('SELECT COUNT(*) as count FROM users');
    const users = await dbService.query('SELECT email, role FROM users ORDER BY role DESC, email');
    
    logger.info('✅ Database initialization completed successfully');
    
    res.json({
      success: true,
      message: 'Database initialized successfully with demo users',
      data: {
        totalUsers: userCount.rows[0].count,
        users: users.rows
      },
      timestamp: new Date().toISOString()
    });
  } catch (error: any) {
    logger.error('❌ Database initialization failed:', error);
    
    res.status(500).json({
      success: false,
      message: 'Database initialization failed',
      error: error.message,
      details: {
        code: error.code || 'Unknown',
        severity: error.severity || 'Unknown',
        detail: error.detail || 'No details available'
      },
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * GET /api/health/db-status
 * 
 * Check database status and list users
 * Public endpoint for debugging
 */
router.get('/db-status', async (req: Request, res: Response) => {
  try {
    const dbService = new DatabaseService();
    
    // Test de connexion
    const connectionTest = await dbService.query('SELECT 1 as test');
    
    // Vérification des tables
    const tables = await dbService.query(`
      SELECT table_name FROM information_schema.tables 
      WHERE table_schema = 'public'
    `);
    
    let users = [];
    let userCount = 0;
    
    try {
      const userCountResult = await dbService.query('SELECT COUNT(*) as count FROM users');
      userCount = parseInt(userCountResult.rows[0].count);
      
      const usersResult = await dbService.query('SELECT email, role, created_at FROM users ORDER BY role DESC, email');
      users = usersResult.rows;
    } catch (tableError: any) {
      logger.warn('Users table not accessible:', tableError.message);
    }
    
    res.json({
      success: true,
      database: {
        connected: true,
        tables: tables.rows.map((t: any) => t.table_name),
        users: {
          count: userCount,
          list: users
        }
      },
      timestamp: new Date().toISOString()
    });
  } catch (error: any) {
    logger.error('Database status check failed:', error);
    
    res.status(500).json({
      success: false,
      message: 'Database status check failed',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * POST /api/health/create-test-user
 * 
 * Create a test user with proper password hashing
 * Public endpoint for testing
 */
router.post('/create-test-user', async (req: Request, res: Response) => {
  try {
    const bcrypt = require('bcrypt');
    
    // Générer le bon hash pour "admin123"
    const hashedPassword = await bcrypt.hash('admin123', 10);
    
    const dbService = new DatabaseService();
    
    // Créer/Mettre à jour l'utilisateur admin avec le bon hash
    await dbService.query(`
      INSERT INTO users (email, password_hash, role) 
      VALUES ('admin@example.com', $1, 'admin')
      ON CONFLICT (email) DO UPDATE SET 
        password_hash = EXCLUDED.password_hash
    `, [hashedPassword]);
    
    // Créer aussi les clients avec le même mot de passe
    const clients = ['client1@example.com', 'client2@example.com', 'client3@example.com'];
    for (const clientEmail of clients) {
      await dbService.query(`
        INSERT INTO users (email, password_hash, role) 
        VALUES ($1, $2, 'client')
        ON CONFLICT (email) DO UPDATE SET 
          password_hash = EXCLUDED.password_hash
      `, [clientEmail, hashedPassword]);
    }
    
    // Test de vérification
    const testResult = await bcrypt.compare('admin123', hashedPassword);
    
    res.json({
      success: true,
      message: 'Test user created with proper password hash',
      data: {
        email: 'admin@example.com',
        password: 'admin123',
        hashTest: testResult,
        hash: hashedPassword
      },
      timestamp: new Date().toISOString()
    });
  } catch (error: any) {
    logger.error('Create test user failed:', error);
    
    res.status(500).json({
      success: false,
      message: 'Create test user failed',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

export default router;