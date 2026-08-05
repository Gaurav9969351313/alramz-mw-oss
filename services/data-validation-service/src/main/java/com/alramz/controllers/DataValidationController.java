package com.alramz.controllers;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.alramz.api.IbanApi;
import com.alramz.model.GenericResponse;
import com.alramz.model.IBANRequest;
import com.alramz.service.IBANValidationService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class DataValidationController implements IbanApi {

    private final IBANValidationService ibanValidationService;

    @Override
    public ResponseEntity<GenericResponse> validateIBAN(IBANRequest ibANRequest) {
        return ResponseEntity.ok(ibanValidationService.validate(ibANRequest));
    }
}
