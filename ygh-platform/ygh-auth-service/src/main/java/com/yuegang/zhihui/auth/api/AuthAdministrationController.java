package com.yuegang.zhihui.auth.api;

import com.yuegang.zhihui.auth.api.dto.*;
import com.yuegang.zhihui.auth.application.AccountAdministrationService;
import com.yuegang.zhihui.common.core.*;
import com.yuegang.zhihui.common.security.CurrentUserPrincipal;
import com.yuegang.zhihui.common.web.TraceIdResolver;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/v1/auth/admin/users")
public final class AuthAdministrationController {
    private final AccountAdministrationService service; private final AuthTrustedUserContextResolver users;
    public AuthAdministrationController(AccountAdministrationService service,AuthTrustedUserContextResolver users){this.service=service;this.users=users;}
    @PutMapping("/{userId}/status") public ApiResponse<AccountStatusResponse> change(@PathVariable String userId,@Valid @RequestBody ChangeAccountStatusRequest body,HttpServletRequest request){
        CurrentUserPrincipal operator=users.resolve(request);if(!operator.roles().contains("ADMIN"))throw new BusinessException(ErrorCode.PERMISSION_DENIED);
        return ApiResponse.success(service.change(userId,body,Long.parseLong(operator.userId())),TraceIdResolver.resolve(request));
    }
}
