# Use official Nginx image
FROM nginx:alpine

# Copy your frontend files (replace 'dist' with your actual build folder)
COPY services/static/ /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
