FROM maven AS build

WORKDIR /app

ARG MAVEN_SETTINGS=""
COPY pom.xml .

RUN --mount=type=cache,target=/root/.m2,id=maven-repo \
    if [ -n "$MAVEN_SETTINGS" ]; then echo "$MAVEN_SETTINGS" | base64 -d > /root/.m2/settings.xml; fi

RUN --mount=type=cache,target=/root/.m2,id=maven-repo \
    if [ -n "$MAVEN_SETTINGS" ]; then mvn dependency:go-offline -B -s /root/.m2/settings.xml; else mvn dependency:go-offline -B; fi

COPY src ./src

RUN --mount=type=cache,target=/root/.m2,id=maven-repo \
    if [ -n "$MAVEN_SETTINGS" ]; then mvn clean package -DskipTests -s /root/.m2/settings.xml; else mvn clean package -DskipTests; fi

FROM eclipse-temurin:21-jdk AS final

WORKDIR /app
COPY --from=build /app/target/data-validation-service-*.jar app.jar
EXPOSE 5001
ENTRYPOINT ["java", "-jar", "app.jar"]
