package com.alramz.service.impl;

import com.alramz.client.ETradeClient;
import com.alramz.config.ETradeTokenProvider;
import com.alramz.exception.ExternalSystemException;
import com.alramz.exceptions.ApiCallFailedException;
import com.alramz.model.ETradeResponse;
import com.alramz.service.DuplicateCheckService;
import com.alramz.service.impl.NinTradingNumberValidationService;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.times;

@ExtendWith(MockitoExtension.class)
class DuplicateCheckServiceImplTest {

    @Mock
    private ETradeTokenProvider etradeTokenProvider;

    @Mock
    private ETradeClient etradeClient;

    @Mock
    private NinTradingNumberValidationService ninTradingNumberValidationService;

    private DuplicateCheckServiceImpl duplicateCheckService;

    private JsonNode mockResData(String json) {
        try {
            return new com.fasterxml.jackson.databind.ObjectMapper().readTree(json);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @BeforeEach
    void setUp() {
        duplicateCheckService = new DuplicateCheckServiceImpl(etradeTokenProvider, etradeClient);
        try {
            java.lang.reflect.Field field = DuplicateCheckServiceImpl.class.getDeclaredField("ninTradingNumberValidationService");
            field.setAccessible(true);
            field.set(duplicateCheckService, ninTradingNumberValidationService);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @Test
    void checkDuplicates_shouldReturnAllFalseWhenAllNull() {
        boolean[] result = duplicateCheckService.checkDuplicates(null, null, null, null);

        assertThat(result).hasSize(4);
        assertThat(result).containsExactly(false, false, false, false);
    }

    @Test
    void checkDuplicates_shouldCheckNinWhenProvided() {
        when(ninTradingNumberValidationService.checkIfNinOrTradingNumberExists("DFM", "NIN123", null))
                .thenReturn(true);

        boolean[] result = duplicateCheckService.checkDuplicates("NIN123", null, null, null);

        assertThat(result).containsExactly(true, false, false, false);
        verify(ninTradingNumberValidationService).checkIfNinOrTradingNumberExists("DFM", "NIN123", null);
    }

    @Test
    void checkDuplicates_shouldCheckEidWhenProvided() {
        when(etradeTokenProvider.getToken()).thenReturn(Optional.of("token"));
        when(etradeClient.callETrade(anyString(), anyString(), anyString(), any(), any()))
                .thenReturn(new ETradeResponse("0", null, null, null, mockResData("{\"Exists\":true}"), true));

        boolean[] result = duplicateCheckService.checkDuplicates(null, "EID123", null, null);

        assertThat(result).containsExactly(false, true, false, false);
    }

    @Test
    void checkDuplicates_shouldCheckEmailWhenProvided() {
        when(etradeTokenProvider.getToken()).thenReturn(Optional.of("token"));
        when(etradeClient.callETrade(anyString(), anyString(), anyString(), any(), any()))
                .thenReturn(new ETradeResponse("0", null, null, null, mockResData("{\"Exists\":true}"), true));

        boolean[] result = duplicateCheckService.checkDuplicates(null, null, "test@example.com", null);

        assertThat(result).containsExactly(false, false, true, false);
    }

    @Test
    void checkDuplicates_shouldCheckPassportWhenProvided() {
        when(etradeTokenProvider.getToken()).thenReturn(Optional.of("token"));
        when(etradeClient.callETrade(anyString(), anyString(), anyString(), any(), any()))
                .thenReturn(new ETradeResponse("0", null, null, null, mockResData("{\"Exists\":true}"), true));

        boolean[] result = duplicateCheckService.checkDuplicates(null, null, null, "P1234567");

        assertThat(result).containsExactly(false, false, false, true);
    }

    @Test
    void checkDuplicates_shouldThrowExternalSystemExceptionWhenNinServiceUnavailable() {
        DuplicateCheckServiceImpl serviceWithoutNin = new DuplicateCheckServiceImpl(etradeTokenProvider, etradeClient);
        try {
            java.lang.reflect.Field field = DuplicateCheckServiceImpl.class.getDeclaredField("ninTradingNumberValidationService");
            field.setAccessible(true);
            field.set(serviceWithoutNin, null);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        assertThatThrownBy(() -> serviceWithoutNin.checkDuplicates("NIN123", null, null, null))
                .isInstanceOf(ExternalSystemException.class)
                .hasMessageContaining("NIN duplicate check service is unavailable");
    }

    @Test
    void checkDuplicates_shouldThrowExternalSystemExceptionWhenTokenMissing() {
        when(etradeTokenProvider.getToken()).thenReturn(Optional.empty());

        assertThatThrownBy(() -> duplicateCheckService.checkDuplicates(null, null, "test@example.com", null))
                .isInstanceOf(ExternalSystemException.class)
                .hasMessageContaining("Failed to obtain eTrade access token");
    }

    @Test
    void checkDuplicates_shouldThrowExternalSystemExceptionWhenETradeReturnsError() {
        when(etradeTokenProvider.getToken()).thenReturn(Optional.of("token"));
        when(etradeClient.callETrade(anyString(), anyString(), anyString(), any(), any()))
                .thenReturn(new ETradeResponse("1", null, null, null, mockResData("{\"message\":\"error\"}"), null));

        assertThatThrownBy(() -> duplicateCheckService.checkDuplicates(null, null, "test@example.com", null))
                .isInstanceOf(ExternalSystemException.class)
                .hasMessageContaining("eTrade duplicate check failed");
    }

    @Test
    void checkDuplicates_shouldRetryOn401AndSucceed() {
        when(etradeTokenProvider.getToken()).thenReturn(Optional.of("token"));

        ApiCallFailedException apiException = new ApiCallFailedException("/path", "POST", 401, "Unauthorized");
        when(etradeClient.callETrade(anyString(), anyString(), anyString(), any(), any()))
                .thenThrow(apiException)
                .thenReturn(new ETradeResponse("0", null, null, null, mockResData("{\"Exists\":true}"), true));

        boolean[] result = duplicateCheckService.checkDuplicates(null, null, "test@example.com", null);

        assertThat(result).containsExactly(false, false, true, false);
        verify(etradeTokenProvider, times(2)).getToken();
    }

    @Test
    void checkDuplicates_shouldThrowExternalSystemExceptionOn401RetryFailure() {
        when(etradeTokenProvider.getToken()).thenReturn(Optional.of("token"), Optional.empty());

        ApiCallFailedException apiException = new ApiCallFailedException("/path", "POST", 401, "Unauthorized");
        when(etradeClient.callETrade(anyString(), anyString(), anyString(), any(), any()))
                .thenThrow(apiException);

        assertThatThrownBy(() -> duplicateCheckService.checkDuplicates(null, null, "test@example.com", null))
                .isInstanceOf(ExternalSystemException.class)
                .hasMessageContaining("Failed to obtain fresh eTrade access token after 401");
    }

    @Test
    void checkDuplicates_shouldThrowExternalSystemExceptionOnNon401Error() {
        when(etradeTokenProvider.getToken()).thenReturn(Optional.of("token"));

        ApiCallFailedException apiException = new ApiCallFailedException("/path", "POST", 500, "Server Error");
        when(etradeClient.callETrade(anyString(), anyString(), anyString(), any(), any()))
                .thenThrow(apiException);

        assertThatThrownBy(() -> duplicateCheckService.checkDuplicates(null, null, "test@example.com", null))
                .isInstanceOf(ExternalSystemException.class)
                .hasMessageContaining("eTrade duplicate check service unavailable");
    }
}
