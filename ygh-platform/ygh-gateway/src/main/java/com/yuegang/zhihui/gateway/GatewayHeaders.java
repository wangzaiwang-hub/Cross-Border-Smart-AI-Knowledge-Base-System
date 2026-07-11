package com.yuegang.zhihui.gateway;

/** Edge headers shared only inside the Gateway module. */
interface GatewayHeaders {

    String TRACE_ID = "X-Trace-Id";
    String REQUEST_ID = "X-Request-Id";
    String USER_ID = "X-YGH-User-Id";
    String ROLES = "X-YGH-Roles";
    String PERMISSIONS = "X-YGH-Permissions";
}
