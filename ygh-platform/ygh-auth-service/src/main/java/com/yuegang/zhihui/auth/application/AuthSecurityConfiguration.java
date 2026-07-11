package com.yuegang.zhihui.auth.application;

import com.yuegang.zhihui.auth.domain.AccountLockPolicy;
import com.yuegang.zhihui.auth.domain.AccountSecurityRepository;
import com.yuegang.zhihui.auth.domain.Argon2PasswordHasher;
import com.yuegang.zhihui.auth.domain.PasswordPolicy;
import com.yuegang.zhihui.auth.domain.RefreshTokenRepository;
import com.yuegang.zhihui.auth.infrastructure.ClasspathCompromisedPasswordChecker;
import com.yuegang.zhihui.auth.infrastructure.JdbcAccountSecurityRepository;
import com.yuegang.zhihui.auth.infrastructure.JdbcRefreshTokenRepository;
import java.time.Clock;
import java.time.Duration;
import javax.sql.DataSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
class AuthSecurityConfiguration {

    @Bean
    PasswordPolicy passwordPolicy() {
        return new PasswordPolicy(
                PasswordPolicy.MIN_LENGTH, PasswordPolicy.MAX_LENGTH,
                new ClasspathCompromisedPasswordChecker());
    }

    @Bean
    Argon2PasswordHasher argon2PasswordHasher() {
        return Argon2PasswordHasher.owaspMinimum();
    }

    @Bean
    AccountLockPolicy accountLockPolicy() {
        return new AccountLockPolicy(5, Duration.ofMinutes(15));
    }

    @Bean
    AccountSecurityRepository accountSecurityRepository(DataSource dataSource) {
        return new JdbcAccountSecurityRepository(dataSource);
    }

    @Bean
    RefreshTokenRepository refreshTokenRepository(DataSource dataSource) {
        return new JdbcRefreshTokenRepository(dataSource);
    }

    @Bean
    OpaqueRefreshTokenService opaqueRefreshTokenService(
            RefreshTokenRepository repository,
            Clock clock,
            @org.springframework.beans.factory.annotation.Value("${ygh.security.jwt.refresh-token-days:14}") long lifetimeDays) {
        return new OpaqueRefreshTokenService(repository, clock, Duration.ofDays(lifetimeDays));
    }

    @Bean
    AccountLockService accountLockService(
            AccountSecurityRepository repository,
            AccountLockPolicy policy,
            Clock clock) {
        return new AccountLockService(repository, policy, clock);
    }
}
