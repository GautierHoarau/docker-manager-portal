import { useState, useEffect } from 'react';
import { io, Socket } from 'socket.io-client';

export const useSocket = (url?: string) => {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    const getSocketUrl = () => {
      if (url) return url;
      
      // Socket URL spécifique si définie
      if (process.env.NEXT_PUBLIC_SOCKET_URL) {
        return process.env.NEXT_PUBLIC_SOCKET_URL;
      }
      
      // En production, utilise l'URL du backend (même que l'API)
      if (process.env.NODE_ENV === 'production' && process.env.NEXT_PUBLIC_API_URL) {
        return process.env.NEXT_PUBLIC_API_URL;
      }
      
      // En développement local
      if (process.env.NODE_ENV === 'development') {
        return 'http://localhost:5000';
      }
      
      // Fallback pour production sans config explicite
      return window.location.origin;
    };
    
    const socketUrl = getSocketUrl();
    
    // Debug info pour Socket.IO
    console.log('[Socket.IO] Connecting to:', socketUrl);
    const newSocket = io(socketUrl, {
      transports: ['websocket', 'polling'],
    });

    newSocket.on('connect', () => {
      setIsConnected(true);
    });

    newSocket.on('disconnect', () => {
      setIsConnected(false);
    });

    setSocket(newSocket);

    return () => {
      newSocket.close();
    };
  }, [url]);

  return { socket, isConnected };
};