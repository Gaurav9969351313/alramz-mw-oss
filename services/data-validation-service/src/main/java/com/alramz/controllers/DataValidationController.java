package com.alramz.controllers;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.alramz.api.IbanApi;
import com.alramz.model.ApiResponseIBAN;
import com.alramz.model.IBANRequest;
import com.alramz.model.IBANValidationResponse;
import com.alramz.service.IBANValidationService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class DataValidationController implements IbanApi {
    
    private final IBANValidationService ibanValidationService;
    
    @Override
    public ResponseEntity<ApiResponseIBAN> validateIBAN(@Valid IBANRequest ibANRequest) {
        IBANValidationResponse validationResponse = ibanValidationService.validate(ibANRequest);
        ApiResponseIBAN response = new ApiResponseIBAN();
        response.setResponse(validationResponse);
        response.setResponseMessage("OK");
        response.setResponseCode(String.valueOf(HttpStatus.OK.value()));
        return ResponseEntity.ok(response);
    }
    
}
