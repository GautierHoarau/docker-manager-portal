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
import { dockerService } from '../services/dockerService';

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
    // Get real clients from container data
    const containers = await dockerService.listContainers();
    
    // Extract unique client IDs from containers
    const clientIds = [...new Set(containers.map((c: any) => c.clientId).filter((id: any) => id && id !== 'unknown'))];
    
    const clients = (clientIds as string[]).map((clientId: string) => {
      const clientContainers = containers.filter((c: any) => c.clientId === clientId);
      return {
        id: clientId,
        name: clientId.replace('-', ' ').replace(/\b\w/g, (l: string) => l.toUpperCase()),
        email: `${clientId}@example.com`,
        createdAt: new Date().toISOString(),
        isActive: true,
        containerQuota: 10,
        usedContainers: clientContainers.length
      };
    });

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
    // Get real containers from Docker API
    const containers = await dockerService.listContainers();
    
    // Filter out management containers and format for admin view
    const adminContainers = containers
      .filter((container: any) => !container.name?.includes('container-manager'))
      .map((container: any) => ({
        id: container.id,
        name: container.name,
        clientId: container.clientId || 'unknown',
        serviceType: container.serviceType || 'custom',
        status: container.status,
        image: container.image,
        ports: container.ports,
        createdAt: container.created,
        url: container.url
      }));

    logger.info(`Admin ${req.user?.email} retrieved all containers`);
    
    res.json({
      success: true,
      data: adminContainers
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

    // Perform the actual Docker action
    try {
      switch (action) {
        case 'start':
          await dockerService.startContainer(id);
          break;
        case 'stop':
          await dockerService.stopContainer(id);
          break;
        case 'restart':
          await dockerService.restartContainer(id);
          break;
        case 'remove':
          await dockerService.removeContainer(id);
          break;
      }
    } catch (dockerError: any) {
      logger.error(`Docker ${action} failed for container ${id}:`, dockerError);
      return res.status(500).json({
        success: false,
        message: `Failed to ${action} container: ${dockerError.message}`
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