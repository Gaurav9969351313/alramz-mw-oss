package com.alramz.controllers;

import com.alramz.api.DfmOnboardingApi;
import com.alramz.api.ExistingDataApi;
import com.alramz.api.IbanApi;
import com.alramz.api.VeriPhoneApi;
import com.alramz.jwt.annotation.JwtSecured;
import com.alramz.model.OnboardingRequest;
import com.alramz.model.OnboardingResponse;
import com.alramz.service.OnboardingService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.alramz.model.GenericResponse;
import com.alramz.model.IBANRequest;
import com.alramz.model.PhoneRequest;
import com.alramz.model.ValidationRequest;
import com.alramz.service.IBANValidationService;
import com.alramz.service.PhoneValidationService;
import com.alramz.service.ValidationService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class DataValidationController implements IbanApi, VeriPhoneApi, ExistingDataApi, DfmOnboardingApi {

    private final IBANValidationService ibanValidationService;
    private final PhoneValidationService phoneValidationService;
    private final ValidationService validationService;
    private final OnboardingService onboardingService;

    @Override
    @JwtSecured(roles = "APP_DATA_VALIDATION")
    public ResponseEntity<GenericResponse> validateIBAN(IBANRequest ibANRequest) {
        return ResponseEntity.ok(ibanValidationService.validate(ibANRequest));
    }

    @Override
    @JwtSecured(roles = "APP_DATA_VALIDATION")
    public ResponseEntity<GenericResponse> verifyPhone(PhoneRequest phoneRequest) {
        return ResponseEntity.ok(phoneValidationService.validate(phoneRequest));
    }

    @Override
    @JwtSecured(roles = "APP_DATA_VALIDATION")
    public ResponseEntity<GenericResponse> validateExistingData(ValidationRequest validationRequest) {
        return ResponseEntity.ok(validationService.validate(validationRequest));
    }

    @Override
    @JwtSecured(roles = "APP_DATA_VALIDATION")
    public ResponseEntity<OnboardingResponse> onboard(@Valid OnboardingRequest onboardingRequest) {
        return ResponseEntity.ok(onboardingService.onboard(onboardingRequest));
    }
}
