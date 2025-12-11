# Image nginx avec une vraie page de demo
FROM nginx:alpine

# Copier une page HTML personnalisée
COPY index.html /usr/share/nginx/html/

# Exposer le port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]