package com.yuegang.zhihui.gateway;

import com.yuegang.zhihui.common.security.CurrentUserPrincipal;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/** Propagates identity only from a server-authenticated exchange attribute. */
@Component
final class TrustedUserContextFilter implements GlobalFilter, Ordered {

    private static final int MAX_AUTHORITIES = 128;
    private static final int MAX_AUTHORITY_HEADER_LENGTH = 4096;
    private static final Pattern SAFE_USER_ID = Pattern.compile("[A-Za-z0-9][A-Za-z0-9._:-]{0,127}");
    private static final Pattern SAFE_AUTHORITY = Pattern.compile("[A-Za-z][A-Za-z0-9:_-]{0,127}");

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        CurrentUserPrincipal principal = exchange.getAttribute(
                GatewaySecurityAttributes.AUTHENTICATED_PRINCIPAL);
        var request = exchange.getRequest().mutate().headers(headers -> {
            headers.remove(GatewayHeaders.USER_ID);
            headers.remove(GatewayHeaders.ROLES);
            headers.remove(GatewayHeaders.PERMISSIONS);
            if (principal != null) {
                String userId = validatedUserId(principal.userId());
                String roles = encodedAuthorities(principal.roles(), "roles");
                String permissions = encodedAuthorities(principal.permissions(), "permissions");
                headers.set(GatewayHeaders.USER_ID, userId);
                if (!roles.isEmpty()) {
                    headers.set(GatewayHeaders.ROLES, roles);
                }
                if (!permissions.isEmpty()) {
                    headers.set(GatewayHeaders.PERMISSIONS, permissions);
                }
            }
        }).build();
        return chain.filter(exchange.mutate().request(request).build());
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE + 30;
    }

    private static String validatedUserId(String userId) {
        if (!SAFE_USER_ID.matcher(userId).matches()) {
            throw new IllegalArgumentException("trusted userId contains unsafe characters");
        }
        return userId;
    }

    private static String encodedAuthorities(Set<String> authorities, String fieldName) {
        if (authorities.size() > MAX_AUTHORITIES) {
            throw new IllegalArgumentException(fieldName + " exceeds authority count limit");
        }
        String encoded = authorities.stream()
                .peek(value -> {
                    if (!SAFE_AUTHORITY.matcher(value).matches()) {
                        throw new IllegalArgumentException(fieldName + " contains an unsafe authority");
                    }
                })
                .sorted()
                .collect(Collectors.joining(","));
        if (encoded.length() > MAX_AUTHORITY_HEADER_LENGTH) {
            throw new IllegalArgumentException(fieldName + " exceeds header length limit");
        }
        return encoded;
    }
}
