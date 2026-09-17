package com.alramz.referencedata.service;

import com.alramz.referencedata.model.ReferenceData;
import com.alramz.referencedata.repository.ReferenceDataRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

/**
 * DAO service for reference data access.
 * Acts as a thin facade over the repository, validating identifier at the service boundary.
 */
@Service
public class ReferenceDataService {

    private static final Logger logger = LoggerFactory.getLogger(ReferenceDataService.class);

    private final ReferenceDataRepository repository;

    public ReferenceDataService(ReferenceDataRepository repository) {
        this.repository = repository;
        logger.info("[Bean: ReferenceDataService] - Successfully Created");
    }

    /**
     * Find reference data by identifier, identifier type, and status.
     *
     * @param identifier the identifier (required)
     * @param identifierType the identifier type (optional, null to ignore)
     * @param status the status (optional, null to ignore)
     * @return an immutable list of reference data records
     * @throws IllegalArgumentException if identifier is null or blank
     */
    public List<ReferenceData> find(String identifier, String identifierType, String status) {
        validateIdentifier(identifier);
        return repository.find(identifier, identifierType, status);
    }

    /**
     * Find reference data by identifier only.
     *
     * @param identifier the identifier (required)
     * @return an immutable list of reference data records
     * @throws IllegalArgumentException if identifier is null or blank
     */
    public List<ReferenceData> find(String identifier) {
        validateIdentifier(identifier);
        return repository.find(identifier);
    }

    /**
     * Find reference data by identifier and identifier type.
     *
     * @param identifier the identifier (required)
     * @param identifierType the identifier type (required)
     * @return an immutable list of reference data records
     * @throws IllegalArgumentException if identifier is null or blank
     */
    public List<ReferenceData> find(String identifier, String identifierType) {
        validateIdentifier(identifier);
        return repository.find(identifier, identifierType);
    }

    /**
     * Find identifier texts by identifier, identifier type, and status.
     *
     * @param identifier the identifier (required)
     * @param identifierType the identifier type (optional, null to ignore)
     * @param status the status (optional, null to ignore)
     * @return an immutable list of identifier text values
     * @throws IllegalArgumentException if identifier is null or blank
     */
    public List<String> findIdentifierTexts(String identifier, String identifierType, String status) {
        validateIdentifier(identifier);
        return repository.findIdentifierTexts(identifier, identifierType, status);
    }

    /**
     * Find identifier texts by identifier only.
     *
     * @param identifier the identifier (required)
     * @return an immutable list of identifier text values
     * @throws IllegalArgumentException if identifier is null or blank
     */
    public List<String> findIdentifierTexts(String identifier) {
        validateIdentifier(identifier);
        return repository.findIdentifierTexts(identifier, null, null);
    }

    /**
     * Find reference data as a map where the key is the identifier.
     * Since IDENTIFIER is unique, the map contains at most one entry.
     *
     * @param identifier the identifier (required)
     * @return an immutable map with identifier as key and immutable list of texts as value
     * @throws IllegalArgumentException if identifier is null or blank
     */
    public Map<String, List<String>> findAsMap(String identifier) {
        validateIdentifier(identifier);
        return repository.findAsMap(identifier);
    }

    /**
     * Update identifier text for matching records.
     *
     * @param identifier the identifier (required)
     * @param identifierType the identifier type (required)
     * @param identifierText the new identifier text
     * @param status the status (required)
     * @return the number of rows affected
     * @throws IllegalArgumentException if identifier is null or blank
     */
    public int updateIdentifierText(String identifier, String identifierType, String identifierText, String status) {
        validateIdentifier(identifier);
        return repository.updateIdentifierText(identifier, identifierType, identifierText, status);
    }

    private void validateIdentifier(String identifier) {
        if (identifier == null || identifier.isBlank()) {
            throw new IllegalArgumentException("identifier cannot be null or blank");
        }
    }
}
