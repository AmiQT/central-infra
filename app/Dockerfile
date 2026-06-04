# Minimal demo image for the CI/CD pipeline.
# CI builds this, pushes to ECR with a git-SHA tag, and deploys it to k3s.
FROM nginx:alpine

# Replace the default page so a successful deploy is visibly different.
COPY index.html /usr/share/nginx/html/index.html
