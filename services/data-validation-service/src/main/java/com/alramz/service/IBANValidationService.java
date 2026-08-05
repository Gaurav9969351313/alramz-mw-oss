package com.alramz.service;

import com.alramz.model.IBANRequest;
import com.alramz.model.IBANValidationResponse;

public interface IBANValidationService {
    IBANValidationResponse validate(IBANRequest request);
}
