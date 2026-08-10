package com.alramz.utils;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;


import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@RequiredArgsConstructor
public class SqlQueriesManager {

    private static Properties props;

    private final Environment environment;

    public String getSQLQueryFromConfig(String key) throws IOException {
        if (props == null) {
            log.info("Loading config from " + environment.getRequiredProperty("sql.file"));
            loadSQLQueriesFromFile();
            if (props == null) {
                log.error("Error: Loading allConfigs from " + environment.getRequiredProperty("sql.file")
                        + " return null.");
                return null;
            }
        }
        return props.getProperty(key);
    }

    private synchronized void loadSQLQueriesFromFile() throws IOException {
        try {
            log.info("Initializing SQL Query Manager");
            
            String sqlFile = environment.getRequiredProperty("sql.file");
            if (sqlFile.startsWith("classpath:")) {
                sqlFile = sqlFile.substring("classpath:".length());
            }
            
            InputStream in = getClass().getClassLoader().getResourceAsStream(sqlFile);
        
            if (in == null) {
                throw new IOException("Error: InputStream is null.");
            }

            if (props == null) {
                props = new Properties();
            }
            props.loadFromXML(in);

            log.info("Loaded  SQL Config:: ");
        } finally {
        }
    }
}
