# Use official Nginx image
FROM nginx:alpine

# Copy your frontend files (replace 'dist' with your actual build folder)
COPY ./dist /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
