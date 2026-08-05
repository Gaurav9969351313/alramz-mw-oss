package com.alramz.controllers;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.alramz.api.IbanApi;
import com.alramz.api.VeriPhoneApi;
import com.alramz.model.GenericResponse;
import com.alramz.model.IBANRequest;
import com.alramz.model.PhoneRequest;
import com.alramz.service.IBANValidationService;
import com.alramz.service.PhoneValidationService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class DataValidationController implements IbanApi, VeriPhoneApi {

    private final IBANValidationService ibanValidationService;
    private final PhoneValidationService phoneValidationService;

    @Override
    public ResponseEntity<GenericResponse> validateIBAN(IBANRequest ibANRequest) {
        return ResponseEntity.ok(ibanValidationService.validate(ibANRequest));
    }

    @Override
    public ResponseEntity<GenericResponse> verifyPhone(PhoneRequest phoneRequest) {
        return ResponseEntity.ok(phoneValidationService.validate(phoneRequest));
    }
}