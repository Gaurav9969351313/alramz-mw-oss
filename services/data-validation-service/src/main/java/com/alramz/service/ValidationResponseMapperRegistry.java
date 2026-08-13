package com.alramz.service;

import com.alramz.model.ValidationRequest.ValidationTypeEnum;
import com.alramz.service.impl.EmailExistsResponseMapper;
import com.alramz.service.impl.NinExistsResponseMapper;
import com.alramz.service.impl.PassportExistsResponseMapper;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
public class ValidationResponseMapperRegistry {

    private final Map<ValidationTypeEnum, ValidationResponseMapper> mappers;

    public ValidationResponseMapperRegistry(EmailExistsResponseMapper emailMapper,
                                            PassportExistsResponseMapper passportMapper,
                                            NinExistsResponseMapper ninMapper) {
        this.mappers = Map.of(
                ValidationTypeEnum.EMAIL_EXISTS, emailMapper,
                ValidationTypeEnum.PASSPORT_EXISTS, passportMapper,
                ValidationTypeEnum.NIN_EXISTS, ninMapper
        );
    }

    public ValidationResponseMapper get(ValidationTypeEnum type) {
        ValidationResponseMapper mapper = mappers.get(type);
        if (mapper == null) {
            throw new IllegalArgumentException("No response mapper found for type: " + type);
        }
        return mapper;
    }
}
