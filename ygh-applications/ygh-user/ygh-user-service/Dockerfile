FROM eclipse-temurin:25.0.3_9-jre-alpine-3.23
ARG APP_VERSION=dev
ARG GIT_SHA=unknown
ARG BUILD_TIME=unknown
LABEL org.opencontainers.image.version="${APP_VERSION}" org.opencontainers.image.revision="${GIT_SHA}" org.opencontainers.image.created="${BUILD_TIME}" org.opencontainers.image.source="https://github.com/wangzaiwang-hub/Cross-Border-Smart-AI-Knowledge-Base-System"
RUN addgroup -S ygh && adduser -S -G ygh -u 10001 ygh
WORKDIR /app
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
USER 10001:10001
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/urandom"
EXPOSE 8082
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD wget -qO- http://127.0.0.1:8082/actuator/health/readiness || exit 1
ENTRYPOINT ["java","-jar","/app/app.jar"]
