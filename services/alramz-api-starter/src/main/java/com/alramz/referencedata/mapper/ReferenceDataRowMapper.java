package com.alramz.referencedata.mapper;

import com.alramz.referencedata.model.ReferenceData;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.ResultSet;
import java.sql.SQLException;

@Component
public class ReferenceDataRowMapper implements RowMapper<ReferenceData> {

    private static final Logger logger = LoggerFactory.getLogger(ReferenceDataRowMapper.class);

    public ReferenceDataRowMapper() {
        logger.info("[Bean: ReferenceDataRowMapper] - Successfully Created");
    }

    @Override
    public ReferenceData mapRow(ResultSet rs, int rowNum) throws SQLException {
        return new ReferenceData(
            rs.getLong("ID"),
            rs.getString("IDENTIFIER"),
            rs.getString("IDENTIFIER_TYPE"),
            rs.getString("IDENTIFIER_TEXT"),
            rs.getString("STATUS")
        );
    }
}
