FROM nginx:alpine
WORKDIR /usr/share/nginx/html
COPY . .
RUN rm -f Dockerfile Jenkinsfile sonar-project.properties README.md
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
