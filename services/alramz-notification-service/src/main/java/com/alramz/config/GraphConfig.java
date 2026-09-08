package com.alramz.config;

import com.azure.core.credential.AccessToken;
import com.azure.core.credential.TokenRequestContext;
import com.azure.identity.ClientSecretCredential;
import com.azure.identity.ClientSecretCredentialBuilder;
import com.microsoft.graph.requests.GraphServiceClient;
import com.microsoft.graph.authentication.TokenCredentialAuthProvider;
import com.alramz.utils.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
@EnableConfigurationProperties(GraphProperties.class)
public class GraphConfig {

    private static final Logger log = LoggerFactory.getLogger(GraphConfig.class);

    @Bean
    @ConditionalOnProperty(name = "app.email.service-provider", havingValue = "MICROSOFT_GRAPH")
    public GraphServiceClient<?> graphServiceClient(GraphProperties properties) {
        String tenantId = StringUtils.requireNonBlank(properties.tenantId(), "tenant-id");
        String clientId = StringUtils.requireNonBlank(properties.clientId(), "client-id");
        String clientSecret = StringUtils.requireNonBlank(properties.clientSecret(), "client-secret");

        String scopes = properties.graphScopes() != null && !properties.graphScopes().isEmpty()
                ? properties.graphScopes()
                : "https://graph.microsoft.com/.default";

        if (log.isInfoEnabled()) {
            log.info("Configuring GraphServiceClient");
        }

        ClientSecretCredential credential = new ClientSecretCredentialBuilder()
                .tenantId(tenantId)
                .clientId(clientId)
                .clientSecret(clientSecret)
                .build();

        AccessToken accessToken = credential.getToken(new TokenRequestContext().addScopes(scopes)).block();
        if (log.isInfoEnabled()) {
            log.info("Access Token: {}", accessToken.getToken());
        }

        TokenCredentialAuthProvider authProvider =
                new TokenCredentialAuthProvider(
                        List.of(scopes),
                        credential);

        GraphServiceClient<?> graphClient = GraphServiceClient
                .builder()
                .authenticationProvider(authProvider)
                .buildClient();

        if (log.isInfoEnabled()) {
            log.info("=========== GraphServiceClient configured successfully =============");
        }
        return graphClient;
    }
}
