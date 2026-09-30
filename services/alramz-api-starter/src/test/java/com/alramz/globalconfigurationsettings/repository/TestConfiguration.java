package com.alramz.referencedata.repository;

import com.alramz.utils.SqlQueriesManager;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import javax.sql.DataSource;

@TestConfiguration
@Import({
    com.alramz.referencedata.config.ReferenceDataAutoConfiguration.class,
    SqlQueriesManager.class
})
public class ReferenceDataTestConfiguration {

    @Bean(name = "middlewareNamedParameterJdbcTemplate")
    public NamedParameterJdbcTemplate middlewareNamedParameterJdbcTemplate(DataSource dataSource) {
        return new NamedParameterJdbcTemplate(new JdbcTemplate(dataSource));
    }
}
