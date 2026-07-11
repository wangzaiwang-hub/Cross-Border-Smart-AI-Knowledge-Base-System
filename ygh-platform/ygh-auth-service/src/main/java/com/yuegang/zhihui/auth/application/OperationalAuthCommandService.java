package com.yuegang.zhihui.auth.application;

import com.yuegang.zhihui.auth.api.dto.*;
import com.yuegang.zhihui.common.core.BusinessException;
import com.yuegang.zhihui.common.core.ErrorCode;
import java.util.Objects;

/** Operational login adapter; remaining commands are enabled by subsequent authenticated use cases. */
final class OperationalAuthCommandService implements AuthCommandService {
    private final LoginUseCase loginUseCase;

    OperationalAuthCommandService(LoginUseCase loginUseCase) {
        this.loginUseCase = Objects.requireNonNull(loginUseCase, "loginUseCase must not be null");
    }

    @Override public AuthenticationResponse login(LoginRequest request, LoginSecurityContext context) {
        return loginUseCase.login(request, context);
    }

    @Override public AuthenticationResponse register(RegisterRequest request) { throw unavailable(); }
    @Override public TokenResponse refresh(RefreshTokenRequest request) { throw unavailable(); }
    @Override public OperationResponse logout(LogoutRequest request) { throw unavailable(); }
    @Override public CaptchaResponse captcha() { throw unavailable(); }
    @Override public PasswordResetRequestedResponse requestPasswordReset(PasswordResetRequest request) {
        throw unavailable();
    }
    @Override public OperationResponse confirmPasswordReset(PasswordResetConfirmRequest request) {
        throw unavailable();
    }

    private static BusinessException unavailable() {
        return new BusinessException(ErrorCode.DEPENDENCY_UNAVAILABLE);
    }
}
