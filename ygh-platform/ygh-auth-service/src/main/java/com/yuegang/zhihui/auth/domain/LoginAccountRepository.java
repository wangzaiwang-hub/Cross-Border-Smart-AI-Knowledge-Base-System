package com.yuegang.zhihui.auth.domain;

import java.util.Optional;

@FunctionalInterface
public interface LoginAccountRepository {
    Optional<LoginAccount> findByPrincipal(String normalizedPrincipal);
}
