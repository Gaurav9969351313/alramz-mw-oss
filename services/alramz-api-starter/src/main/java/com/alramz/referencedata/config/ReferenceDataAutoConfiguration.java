package com.alramz.referencedata.config;

import com.alramz.referencedata.mapper.ReferenceDataRowMapper;
import com.alramz.referencedata.repository.JdbcReferenceDataRepository;
import com.alramz.referencedata.repository.ReferenceDataRepository;
import com.alramz.referencedata.service.ReferenceDataService;
import com.alramz.utils.SqlQueriesManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

/**
 * Auto-configuration for the reference data framework.
 * Enabled only when the middleware datasource is enabled.
 */
@AutoConfiguration
@ConditionalOnProperty(
    prefix = "company.datasource.middleware",
    name = "enabled",
    havingValue = "true",
    matchIfMissing = false
)
@ConditionalOnBean(name = "middlewareNamedParameterJdbcTemplate")
@Import({
    SqlQueriesManager.class,
    ReferenceDataRowMapper.class
})
public class ReferenceDataAutoConfiguration {

    private static final Logger logger = LoggerFactory.getLogger(ReferenceDataAutoConfiguration.class);

    @Bean
    public ReferenceDataRepository referenceDataRepository(
            @Qualifier("middlewareNamedParameterJdbcTemplate") NamedParameterJdbcTemplate middlewareNamedParameterJdbcTemplate,
            ReferenceDataRowMapper rowMapper,
            SqlQueriesManager sqlQueriesManager
    ) {
        logger.info("[Bean: referenceDataRepository] - Successfully Created");
        return new JdbcReferenceDataRepository(middlewareNamedParameterJdbcTemplate, rowMapper, sqlQueriesManager);
    }

    @Bean
    public ReferenceDataService referenceDataService(ReferenceDataRepository repository) {
        logger.info("[Bean: referenceDataService] - Successfully Created");
        return new ReferenceDataService(repository);
    }
}
