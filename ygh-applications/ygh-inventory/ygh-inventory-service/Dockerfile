FROM eclipse-temurin:25-jre-alpine
RUN addgroup -S ygh && adduser -S -G ygh -u 10001 ygh
WORKDIR /app
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
USER 10001:10001
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/urandom"
EXPOSE 8085
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD wget -qO- http://127.0.0.1:8085/actuator/health/readiness || exit 1
ENTRYPOINT ["java","-jar","/app/app.jar"]
