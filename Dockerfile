# ─── Stage 1: Build ───────────────────────────────────────────────────────────
# Use JDK 21 to match java.version=21 in pom.xml.
# The previous image (eclipse-temurin-17) caused compilation failure because
# Spring Boot 3.4.x and Lombok 1.18.36 require Java 21+ bytecode target.
FROM maven:3.9.9-eclipse-temurin-21 AS builder
WORKDIR /app

# Copy pom.xml first and resolve dependencies in a separate layer.
# This layer is cached and only re-run when pom.xml changes.
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build the JAR.
COPY src ./src
RUN mvn package -DskipTests -B

# ─── Stage 2: Runtime ─────────────────────────────────────────────────────────
# Use a minimal JRE 21 Alpine image for the final image.
# Alpine keeps the image small (~180 MB vs ~500 MB for the full JDK image).
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Run as a non-root user for security.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy only the built JAR from the builder stage.
COPY --from=builder /app/target/stock-predictor-1.0.0.jar app.jar

EXPOSE 8080

# Docker will mark the container UNHEALTHY if the app fails to start
# or crashes after startup. The CI/CD pipeline uses this to detect
# failed deployments.
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "app.jar"]