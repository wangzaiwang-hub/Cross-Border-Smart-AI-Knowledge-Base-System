package com.yuegang.zhihui.common.web;

import static org.assertj.core.api.Assertions.assertThat;

import com.yuegang.zhihui.common.core.BusinessException;
import com.yuegang.zhihui.common.core.ErrorCode;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void mapsBusinessConflictToHttp409AndStableEnvelope() {
        var request = requestWithTraceId("trace-conflict");

        var response = handler.handleBusinessException(
                new BusinessException(ErrorCode.BUSINESS_CONFLICT, "订单状态不允许取消"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo("BUSINESS_CONFLICT");
        assertThat(response.getBody().message()).isEqualTo("订单状态不允许取消");
        assertThat(response.getBody().traceId()).isEqualTo("trace-conflict");
    }

    @Test
    void hidesUnexpectedExceptionDetailsFromClient() {
        var request = requestWithTraceId("trace-error");

        var response = handler.handleUnexpectedException(new IllegalStateException("database password leak"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo("INTERNAL_ERROR");
        assertThat(response.getBody().message()).isEqualTo("系统内部错误");
        assertThat(response.getBody().message()).doesNotContain("password");
    }

    private MockHttpServletRequest requestWithTraceId(String traceId) {
        var request = new MockHttpServletRequest();
        request.setAttribute(TraceIdResolver.TRACE_ID_ATTRIBUTE, traceId);
        return request;
    }
}
