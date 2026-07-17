# Stage 1: Build stage
FROM maven AS builds

WORKDIR /app

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jdk AS final

WORKDIR /app
COPY --from=build /app/target/data-validation-service-*.jar app.jar
EXPOSE 5001
ENTRYPOINT ["java", "-jar", "app.jar"]
RUN rm -rf /app/src /app/.m2