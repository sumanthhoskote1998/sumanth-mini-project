cat > Dockerfile <<'EOF'
# Use Eclipse Temurin (OpenJDK) 17 runtime
FROM eclipse-temurin:17-jre-jammy

ARG JAR_FILE=target/demo-sonar-nexus-ecr-0.1.0.jar
COPY ${JAR_FILE} /app/app.jar
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
EOF

