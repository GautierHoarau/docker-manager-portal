/**
 * Admin Routes for Container Management Platform
 * 
 * Provides admin-only endpoints for:
 * - Client management and overview
 * - System-wide container monitoring
 * - Platform statistics and health
 * 
 * @author Container Platform Team
 * @version 1.0.0
 */

import express, { Response } from 'express';
import { AuthRequest, authenticate, authorize } from '../middleware/auth';
import { logger } from '../utils/logger';

const router = express.Router();

// Apply authentication to all admin routes
router.use(authenticate);
router.use(authorize(['admin']));

/**
 * GET /api/admin/clients
 * 
 * Get all clients in the system (admin only)
 * Returns client information without sensitive data
 */
router.get('/clients', async (req: AuthRequest, res: Response) => {
  try {
    // Mock clients data - in production, this would come from database
    const clients = [
      {
        id: 'client-1',
        name: 'Client One',
        email: 'client1@example.com',
        createdAt: new Date('2024-01-01').toISOString(),
        isActive: true,
        containerQuota: 5,
        usedContainers: 2
      },
      {
        id: 'client-2',
        name: 'Client Two', 
        email: 'client2@example.com',
        createdAt: new Date('2024-01-15').toISOString(),
        isActive: true,
        containerQuota: 3,
        usedContainers: 1
      }
    ];

    logger.info(`Admin ${req.user?.email} retrieved clients list`);
    
    res.json({
      success: true,
      data: clients
    });
  } catch (error) {
    logger.error('Admin get clients error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve clients'
    });
  }
});

/**
 * GET /api/admin/containers
 * 
 * Get all containers across all clients (admin only)
 */
router.get('/containers', async (req: AuthRequest, res: Response) => {
  try {
    // Mock containers data - in production, this would come from Docker API
    const containers = [
      {
        id: 'container-1',
        name: 'client1-nginx-web',
        clientId: 'client-1',
        serviceType: 'web',
        status: 'running',
        image: 'nginx:alpine',
        ports: [{ containerPort: 80, hostPort: 8080 }],
        createdAt: new Date('2024-01-02').toISOString(),
        url: 'http://localhost:8080'
      },
      {
        id: 'container-2',
        name: 'client1-nodejs-api',
        clientId: 'client-1',
        serviceType: 'api',
        status: 'running',
        image: 'node:18-alpine',
        ports: [{ containerPort: 3000, hostPort: 8081 }],
        createdAt: new Date('2024-01-03').toISOString(),
        url: 'http://localhost:8081'
      },
      {
        id: 'container-3',
        name: 'client2-python-worker',
        clientId: 'client-2',
        serviceType: 'worker',
        status: 'exited',
        image: 'python:3.9-alpine',
        ports: [],
        createdAt: new Date('2024-01-16').toISOString()
      }
    ];

    logger.info(`Admin ${req.user?.email} retrieved all containers`);
    
    res.json({
      success: true,
      data: containers
    });
  } catch (error) {
    logger.error('Admin get containers error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve containers'
    });
  }
});

/**
 * GET /api/admin/stats
 * 
 * Get platform statistics (admin only)
 */
router.get('/stats', async (req: AuthRequest, res: Response) => {
  try {
    const stats = {
      totalClients: 2,
      activeClients: 2,
      totalContainers: 3,
      runningContainers: 2,
      stoppedContainers: 1,
      systemLoad: {
        cpu: 25.5,
        memory: 68.3,
        disk: 45.2
      },
      recentActivity: [
        {
          id: '1',
          action: 'container_created',
          resource: 'client1-nginx-web',
          userId: 'client-1',
          timestamp: new Date().toISOString(),
          details: { serviceType: 'web' }
        },
        {
          id: '2',
          action: 'user_login',
          resource: 'admin',
          userId: 'admin-1',
          timestamp: new Date(Date.now() - 300000).toISOString()
        }
      ]
    };

    logger.info(`Admin ${req.user?.email} retrieved platform stats`);
    
    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    logger.error('Admin get stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve platform statistics'
    });
  }
});

/**
 * POST /api/admin/containers/:id/action
 * 
 * Perform action on any container (admin only)
 */
router.post('/containers/:id/:action', async (req: AuthRequest, res: Response) => {
  try {
    const { id, action } = req.params;
    
    // Validate action
    const validActions = ['start', 'stop', 'restart', 'remove'];
    if (!validActions.includes(action)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid action'
      });
    }

    logger.info(`Admin ${req.user?.email} performed ${action} on container ${id}`);
    
    res.json({
      success: true,
      message: `Container ${action} successful`,
      data: { containerId: id, action }
    });
  } catch (error) {
    logger.error('Admin container action error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to perform container action'
    });
  }
});

export default router;